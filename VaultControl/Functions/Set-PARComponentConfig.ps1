Function Set-PARComponentConfig {
	<#
	.SYNOPSIS
	Sets values set in component configuration files

	.DESCRIPTION
	Sets values contained in component configuration files DBPARM.ini or PADR.ini on remote vault server.

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
	The name of the component to query. Vault or PADR are the accepted values

	.PARAMETER Parameter
	The name of the Parameter to set the value for.
	For Vault Components, valid parameter names are:
	"DefaultTimeout", "MTU", "SecurityNotification", "DebugLevel", "DisableExceptionHandling"
	For Disaster Recovery Components, valid parameter names are:
	"EnableCheck", "EnableReplicate", "EnableFailover", "EnableDBSync", "FailoverMode"

	.PARAMETER Value
	The value to set for the parameter in the configuration file

	.PARAMETER Mode
	Specify how or when the paramater value change will take effect.
	For Vault parameter value changes "Temporary", "Permanent" or "Immediate" modes can be specified.

	For Disaster Recovery  parameter value changes only "Permanent" mode can be specified.

	.EXAMPLE
	Set-PARComponentConfig -Server EPV1 -Credential $credential -Component Vault -Parameter DefaultTimeout -Value 300


	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification = "ShouldProcess handling is in Invoke-PARClient")]
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
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[ValidateSet("Vault", "PADR")]
		[string]$Component,

		[Parameter(
			Mandatory = $True,
			ValueFromPipelineByPropertyName = $True,
			ParameterSetName = "PassFile"
		)]
		[string]$PassFile,

		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[ValidateSet("DefaultTimeout", "MTU", "SecurityNotification", "DebugLevel", "DisableExceptionHandling",
			"EnableCheck", "EnableReplicate", "EnableFailover", "EnableDBSync", "FailoverMode")]
		[string]$Parameter,

		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[string]$Value,

		[Parameter(
			Mandatory = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[ValidateSet("Temporary", "Permanent", "Immediate")]
		[string]$Mode

	)

	Process {

		$PSBoundParameters.Add("CommandParameters", "SetParm $Component $Parameter=$Value /$Mode")

		$Result = Invoke-PARClient @PSBoundParameters

		If($Result.StdOut) {

			$Update = ($Result.StdOut | Select-String '(success|Error)' -AllMatches)

			[PSCustomObject]@{

				"Server"    = $Result.Server
				"Component" = $Component
				"Parameter" = $($PSBoundParameters["Parameter"])
				"Value"     = $Value
				"Mode"      = $($PSBoundParameters["Mode"])
				"Status"    = $($Update.Matches.Groups[1].Value).Substring(0, 1).ToUpper() + $($Update.Matches.Groups[1].Value).Substring(1)
				"Message"   = $Result.StdOut

			}

		}

	}

}