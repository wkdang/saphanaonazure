
Configuration SapHana{
    Import-DscResource -Module nx

    Node "sap-hana"{
        Settings{
            RefreshFrequencyMins = 30;
            RefreshMode = "PULL";
            ConfigurationMode = "ApplyAndMonitor";
            AllowModuleOverwrite = $ture;
            RebooNodeIfNeeded = $false;
            ConfigurationModeFrequencyMins = 60;
        }
    }
}