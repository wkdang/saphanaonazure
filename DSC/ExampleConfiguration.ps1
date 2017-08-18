
Param(
    [Parameter(Mandatory)][string] $Uri
)

Configuration ExampleConfiguration{

    Import-DSCResource -Module nx
    Set-StrictMode -Off

    Node  "sap-hana"{
		nxFile ExampleFile {

			DestinationPath = "/tmp/example"
			Contents = $Uri
			Ensure = "Present"
			Type = "File"
		}

    }
}
ExampleConfiguration -OutputPath:".\"