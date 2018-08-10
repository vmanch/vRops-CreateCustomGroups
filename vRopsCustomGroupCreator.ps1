#Powershell script for creating custom groups in vRops with the suite-api
#v1.0 vMan.ch, 21.06.2016 - Initial Version

#Vars
$vRopsAddress = 'vrops.vMan.ch'
$ScriptPath = (Get-Item -Path ".\" -Verbose).FullName
[DateTime]$NowDate = (Get-date)
[int64]$NowDateEpoc = Get-Date -Date $NowDate.ToUniversalTime() -UFormat %s
$NowDateEpoc = $NowDateEpoc*1000

#Credentials Stuff

    $cred = Import-Clixml -Path "$ScriptPath\Home.xml"

    $vRopsUser = $cred.GetNetworkCredential().Username
    $vRopsPassword = $cred.GetNetworkCredential().Password


#Take all certs.
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#Import Metadata into a PSObject / table

$AttributeImport = @()
$AttributeImport = Import-csv "$ScriptPath\metadata.csv" | select CRITICALITY -Unique

#Create XML, generate group

ForEach($Group in $AttributeImport){

#Create XML Structure and populate variables from the dump

$XMLFile = @('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ops:group xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:ops="http://webservice.vmware.com/vRealizeOpsMgr/1.0/">>
	<ops:resourceKey>
		<ops:name>{0}</ops:name>
		<ops:adapterKindKey>Container</ops:adapterKindKey>
		<ops:resourceKindKey>CRITICALITY</ops:resourceKindKey>
	</ops:resourceKey>
	<ops:membershipDefinition>
				<ops:rule-group>
					<ops:resourceKindKey>
						<ops:resourceKind>VirtualMachine</ops:resourceKind>
						<ops:adapterKind>VMWARE</ops:adapterKind>
 					</ops:resourceKindKey>
					<ops:attributeRules xsi:type="ops:property-condition" key="VMAN|CRITICALITY">
						<ops:compareOperator>EQ</ops:compareOperator>
						<ops:stringValue>{0}</ops:stringValue>
					</ops:attributeRules>
				</ops:rule-group>
	 </ops:membershipDefinition>
 </ops:group>' -f $Group.CRITICALITY
)


[xml]$xmlSend = $XMLFile

#Create URL string for Invoke-RestMethod
$urlsend = 'https://' + $vRopsAddress + '/suite-api/internal/resources/groups'

## Debug 
echo $urlsend

#Send Attribute data to vRops.
$ContentType = "application/xml;charset=utf-8"
$header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$header.Add("Accept", 'application/xml')
$header.Add("X-vRealizeOps-API-use-unsupported", 'true')
Invoke-RestMethod -Method POST -uri $urlsend -Body $xmlSend -Credential $cred -ContentType $ContentType -Headers $header

#CleanUp Variables to make sure we dont update the next object with the same data as the previous one.
Remove-Variable urlsend -ErrorAction SilentlyContinue
Remove-Variable xmlSend -ErrorAction SilentlyContinue
Remove-Variable XMLFile -ErrorAction SilentlyContinue
}