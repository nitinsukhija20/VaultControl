Function Get-PARComponentLog {
	<#
	.SYNOPSIS
	Returns events from remote component log.

	.DESCRIPTION
	Gets events from logs for remote Vault, PADR, CVM or ENE.

	.PARAMETER Server
	The name or address of the remote Vault server to target with PARClient

	.PARAMETER Password
	The password for remote operations via PARClient as a secure string

	.PARAMETER Credential
	The password for remote operations via PARClient held in a credential object

	.PARAMETER PassFile
	The path to a "password" file created by PARClient.exe, containing the encrypted password value used for remote
	operations via PARClient

	.PARAMETER Component
	The name of the component to query. Vault, PADR, CVM or ENE are the accepted values

	.PARAMETER LogFile
	For ENE & CVM Logs, the log file to return must be specified. Accepted values are "Console" or "Trace"

	.PARAMETER TimeFrom
	For Vault or PADR log queries, optionally provide a datetime from which to return the logs from.

	.PARAMETER Lines
	For Vault log queries, optionally provide the number of log lines to return.

	.EXAMPLE
	Get-PARComponentLog -Server EPV1 -Password $SecureString -Component Vault -TimeFrom (Get-Date).AddDays(-1)

	Show events from the ITALOG file on Vault EPV1 from the last 24 hours

	.EXAMPLE
	Get-PARComponentLog -Server EPV1 -Password $SecureString -Component ENE -LogFile Trace

	Show events from the ENE Trace log on vault EPV1

	.EXAMPLE
	Get-PARComponentLog -Server EPV1 -Password $SecureString -Component Vault -Lines 10

	Show the last 10 lines of the ITALOG file on vault EPV1

	#>
	[CmdletBinding()]
	Param(
		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]$Server,

		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true,
			ParameterSetName = "Password"
		)]
		[securestring]$Password,

		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true,
			ParameterSetName = "Credential"
		)]
		[pscredential]$Credential,

		[Parameter(
			Mandatory = $True,
			ValueFromPipelineByPropertyName = $True,
			ParameterSetName = "PassFile"
		)]
		[ValidateScript( {Test-Path $_ -PathType Leaf})]
		[string]$PassFile,

		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[ValidateSet("Vault", "PADR", "ENE", "CVM")]
		[string]$Component,

		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[ValidateSet("Console", "Trace")]
		[string]$LogFile = "Console",

		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[datetime]$TimeFrom,

		[Parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $true
		)]
		[int]$Lines
	)

	Begin {

		$PADR = '^\[(\d+\/\d+\/\d+\s+\d+\:\d+\:\d+\.\d+)\]\W+([A-Z]+\d+[A-Z](?:\s))?(.+)$'
		$Vault = '^(\d+\/\d+\/\d+ \d+:\d+:\d+) ([A-Z]+[0-9]+[A-Z]) (.+)$'
		$ENEConsole = '^\[(\d+\/\d+\/\d+\s\W\s\d+\:\d+\:\d+)\]\W+([A-Z]+\d+[A-Z])\s(.+)$'
		$ENETrace = '^\[(\d+\/\d+\/\d+(?:\s\W)\s\d+\:\d+\:\d+)\.\d+\].+\|\s([A-Z]+(?:[A-Z]|\d)[A-Z]\d+[A-Z](?:\s))?(.+)$'

	}

	Process {

		$Command = "GetLog $Component"

		if(($Component -eq "VAULT") -or ($Component -eq "PADR")) {

			if($PSBoundParameters.ContainsKey("TimeFrom")) {

				$DateStamp = (Get-Date $($PSBoundParameters["TimeFrom"]) -Format ddMMyyyy:HHmm)
				$Command = "$Command /TimeFrom $DateStamp"

			}

		}

		if($Component -eq "VAULT") {

			if($PSBoundParameters.ContainsKey("Lines")) {

				$Command = "$Command /Lines $($PSBoundParameters["Lines"])"

			}

		}

		if(($Component -eq "ENE") -or ($Component -eq "CVM")) {

			$Command = "$Command /LogFile $($PSBoundParameters["LogFile"])"

		}

		$PSBoundParameters.Add("CommandParameters", "$Command")

		switch ($Component) {

			"PADR" {$Pattern = $PADR; break}

			"Vault" {$Pattern = $Vault; break}

			"ENE" {

				if ($($PSBoundParameters["LogFile"]) -eq "Console") {

					$Pattern = $ENEConsole; break

				} elseif ($($PSBoundParameters["LogFile"]) -eq "Trace") {

					$Pattern = $ENETrace; break

				}

			}

			default {$Pattern = '(.+)'; break}

		}

		$Result = Invoke-PARClient @PSBoundParameters

		If($Result.StdOut) {

			($Result.StdOut).Split("`n") | ForEach-Object {

				$event = ($_ | Select-String $Pattern -AllMatches)

				if($event -match '\S') {

					[PSCustomObject]@{

						"Time"    = $event.Matches.Groups[1].Value -replace '(\s\W\s)', ' '
						"Code"    = $event.Matches.Groups[2].Value
						"Message" = $event.Matches.Groups[3].Value

					} | Add-ObjectDetail -typename VaultControl.Log.Component

				}

			}

		}

	}

}