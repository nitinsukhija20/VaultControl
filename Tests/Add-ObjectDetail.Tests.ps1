#Get Current Directory
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

#Get Function Name
$FunctionName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -Replace ".Tests.ps1"

#Assume ModuleName from Repository Root folder
$ModuleName = Split-Path (Split-Path $Here -Parent) -Leaf

#Resolve Path to Module Directory
$ModulePath = Resolve-Path "$Here\..\$ModuleName"

#Define Path to Module Manifest
$ManifestPath = Join-Path "$ModulePath" "$ModuleName.psd1"

if( -not (Get-Module -Name $ModuleName -All)) {

	Import-Module -Name "$ManifestPath"  -ArgumentList $true -Force -ErrorAction Stop

}

BeforeAll {

	#$Script:RequestBody = $null

}

AfterAll {

	#$Script:RequestBody = $null

}

Describe $FunctionName {

	InModuleScope $ModuleName {

		Context "General" {

			BeforeEach {

				$InputObj = [pscustomobject]@{}
				$InputObj | Add-ObjectDetail -TypeName SomeType -PropertyToAdd @{"SomeProperty" = "SomeValue"} -DefaultProperties SomeProperty

			}

			It "Adds Expected Type to Object" {

				$InputObj | get-member | select-object -expandproperty typename -Unique | Should Be "SomeType"

			}

			It "Adds Expected Property to Object" {

				$InputObj.SomeProperty | Should Be "SomeValue"

			}

		}

	}

}