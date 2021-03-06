﻿Function Invoke-PARClient {

	<#
    .SYNOPSIS
	Defines specified PARClient command and arguments

    .DESCRIPTION
	Defines a PARClient process object with arguments required for specific command.

	.PARAMETER PARClient
	The Path to PARClient.exe.
	Defaults to value of $Script:PAR.ClientPath, which is set during module import or via Set-PARConfiguration.

	.PARAMETER Server
	The name or address of the Vault server to target

	.PARAMETER Password
	SecureString of password used for PARClient operations

	.PARAMETER Credential
	A credential object containing the password used for PARClient operations

	.PARAMETER PassFile
	The path to a "password" file created by PARClient.exe, containing the encrypted password value used for remote
	operations via PARClient

	.PARAMETER CommandParameters
	The PARClient command to execute

	.PARAMETER PAROptions
	Additional command parameters. By default specifies /Q /C and /StateFileName.
	StateFileName is set to a file named after the process ID of the script, and with the local temp directory path

	.PARAMETER RemainingArgs
	A catch all parameter, accepts any remaining values from pipeline.
	Intended to suppress errors when piping in an object.

    .EXAMPLE
	Invoke-PARClient -Server EPV1 -Password $SecureString -CommandParameters "GetParm Vault DebugLevel"

	Invokes the GetParm action against the Vault on EPV1 and returns the DebugLevel parameter value.

    .NOTES
    	AUTHOR: Pete Maan

    #>

	[CmdLetBinding(SupportsShouldProcess)]
	param(

		[Parameter(
			Mandatory = $False,
			ValueFromPipelineByPropertyName = $True
		)]
		[string]$PARClient = $Script:PAR.ClientPath,

		[Parameter(
			Mandatory = $False,
			ValueFromPipelineByPropertyName = $True
		)]
		[int]$Port = $Script:PAR.Port,

		[Parameter(
			Mandatory = $True,
			ValueFromPipelineByPropertyName = $True
		)]
		[string]$Server,

		[Parameter(
			Mandatory = $True,
			ValueFromPipelineByPropertyName = $True,
			ParameterSetName = "Password"
		)]
		[securestring]$Password,

		[Parameter(
			Mandatory = $True,
			ValueFromPipelineByPropertyName = $True,
			ParameterSetName = "Credential"
		)]
		[pscredential]$Credential,

		[Parameter(
			Mandatory = $True,
			ValueFromPipelineByPropertyName = $True,
			ParameterSetName = "PassFile"
		)]
		[ValidateScript( {Test-Path $_})]
		[string]$PassFile,

		[Parameter(
			Mandatory = $True,
			ValueFromPipelineByPropertyName = $True
		)]
		[string]$CommandParameters,

		[Parameter(Mandatory = $False,
			ValueFromPipelineByPropertyName = $True
		)]
		[string]$PAROptions = "/StateFileName $(Join-Path $env:temp "$PID.tmp") /Q /C",

		[Parameter(Mandatory = $False,
			ValueFromPipelineByPropertyName = $False,
			ValueFromRemainingArguments = $true
		)]
		$RemainingArgs
	)

	Begin {

		Try {

			Get-Variable -Name PAR -ErrorAction Stop

			if($PAR.PSObject.Properties.Name -notcontains "ClientPath") {

				Write-Error "Heads Up!" -ErrorAction Stop

			}

		} Catch {throw "PARClient.exe not found `nRun Set-PARConfiguration to set path to PARClient"}

		#Create process
		$Process = New-Object System.Diagnostics.Process

	}

	Process {

		Switch($PSCmdlet.ParameterSetName) {

			"Credential" {

				$ClearTextPassword = $($Credential.GetNetworkCredential().Password)
				$PARCommand = "$Server/$ClearTextPassword"; break

			}

			"Password" {

				$ClearTextPassword = ConvertTo-InsecureString -SecureString $Password
				$PARCommand = "$Server/$ClearTextPassword"; break

			}

			"PassFile" {$PARCommand = "$Server /UsePassFile $PassFile"; break}

		}

		If($Port -gt 0) {

			$PARCommand = "$PARCommand /Port $Port"

		}

		$CommandParameters = $CommandParameters -replace ('^', '"')
		$CommandParameters = $CommandParameters -replace ('$', '"')

		if ($PSCmdlet.ShouldProcess($Server, "$CommandParameters")) {

			Write-Debug "Command Arguments: $PARCommand $PAROptions $CommandParameters"

			#Assign process parameters

			$Process.StartInfo.WorkingDirectory = "$(Split-Path $PARClient -Parent)"
			$Process.StartInfo.Filename = $PARClient
			$Process.StartInfo.Arguments = "$PARCommand $PAROptions $CommandParameters"
			$Process.StartInfo.RedirectStandardOutput = $True
			$Process.StartInfo.RedirectStandardError = $True
			$Process.StartInfo.UseShellExecute = $False
			$Process.StartInfo.CreateNoWindow = $True
			$Process.StartInfo.WindowStyle = "hidden"

			#Start Process
			$Result = Start-PARClientProcess -Process $Process

			$Result | Add-Member -MemberType NoteProperty -Name Server -Value $Server

			if($Result.StdOut -match '((?:^[A-Z]{5}[0-9]{3}[A-Z])|(?:ERROR \(\d+\)))(?::)? (.+)$') {

				#PARCL002S Authentication failure.
				Write-Error -Message $Matches[2] -ErrorId $Matches[1]

			} ElseIf($Result.StdOut -match '(.+) \((.+: \d)\)') {

				#Cannot get parameter DisableExceptionHandling. (Reason: 7)
				Write-Error -Message $Matches[1] -ErrorId $Matches[2]

			} Else {$Result}

		}

	}

	End {

		$Process.Dispose()

	}

}