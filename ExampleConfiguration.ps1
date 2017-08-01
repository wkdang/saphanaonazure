Configuration ExampleConfiguration{

        Import-DscResource -Module nx

        Node  "sap-hana"{
        nxFile ExampleFile {

            DestinationPath = "/tmp/example"
            Contents = "hello world `n"
            Ensure = "Present"
            Type = "File"
        }

        }
    }
    ExampleConfiguration -OutputPath:"C:\temp"