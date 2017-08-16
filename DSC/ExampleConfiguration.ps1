Configuration ExampleConfiguration{

        Import-DSCResource -Module nx
        Set-StrictMode -Off

        Node  "sap-hana"{
        nxFile ExampleFile {

            DestinationPath = "/tmp/example"
            Contents = "hello world `n"
            Ensure = "Present"
            Type = "File"
        }

        }
    }
    ExampleConfiguration -OutputPath:".\"