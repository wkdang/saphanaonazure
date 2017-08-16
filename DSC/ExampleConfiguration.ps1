Configuration ExampleConfiguration{

        Param(
            [Parameter(Mandatory)][string] $Uri
        )

        Import-DSCResource -Module nx
        Set-StrictMode -Off

        Node  "sap-hana"{
        nxFile ExampleFile {

            DestinationPath = "/tmp/example"
            Contents = $Url
            Ensure = "Present"
            Type = "File"
        }

        }
    }
    ExampleConfiguration -OutputPath:".\"