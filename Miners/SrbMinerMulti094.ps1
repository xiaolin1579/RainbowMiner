using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD nor CPU present in system

$ManualUri = "https://bitcointalk.org/index.php?topic=5190081.0"
$Port = "350{0:d2}"
$DevFee = 0.85
$Version = "0.9.4"

if ($IsLinux) {
    $Path = ".\Bin\ANY-SRBMinerMulti094\SRBMiner-MULTI"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.4-srbminermulti/SRBMiner-Multi-0-9-4-Linux.tar.xz"
} else {
    $Path = ".\Bin\ANY-SRBMinerMulti094\SRBMiner-MULTI.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.4-srbminermulti/SRBMiner-Multi-0-9-4-win64.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "0x10"             ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #Chainox/CHOX
    [PSCustomObject]@{MainAlgorithm = "argon2d_16000"    ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #Argon2d16000/ADOT
    [PSCustomObject]@{MainAlgorithm = "argon2d_dynamic"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #Argon2Dyn
    [PSCustomObject]@{MainAlgorithm = "argon2id_chukwa"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #Argon2Chukwa
    [PSCustomObject]@{MainAlgorithm = "argon2id_chukwa2" ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #Argon2Chukwa2
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ; DAG = $true; Params = ""; Fee = 2.00;               Vendor = @("AMD")} #Autolykos2/ERGO
    [PSCustomObject]@{MainAlgorithm = "blake2b"          ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD"); CoinSymbols = @("TNET")} #blake2b
    #[PSCustomObject]@{MainAlgorithm = "blake2s"         ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD")} #blake2s
    [PSCustomObject]@{MainAlgorithm = "blake3_alephium"  ;              Params = ""; Fee = 1.00; MinMemGb = 2; Vendor = @("AMD")} #Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "circcash"         ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #Circcash/CIRC
    [PSCustomObject]@{MainAlgorithm = "cryptonight_ccx"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #CryptonightCCX
    [PSCustomObject]@{MainAlgorithm = "cryptonight_gpu"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #CryptonightGPU
    [PSCustomObject]@{MainAlgorithm = "cryptonight_talleo";             Params = ""; Fee = 0.00;               Vendor = @("AMD")} #CryptonightTalleo
    [PSCustomObject]@{MainAlgorithm = "cryptonight_turtle";             Params = ""; Fee = 0.85;               Vendor = @("AMD")} #CryptonightTurtle
    [PSCustomObject]@{MainAlgorithm = "cryptonight_upx"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #CryptonightUPX
    [PSCustomObject]@{MainAlgorithm = "cryptonight_xhv"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #CryptonightXHV
    [PSCustomObject]@{MainAlgorithm = "dynamo"           ;              Params = ""; Fee = 1.00;               Vendor = @("AMD"); ExcludeYiimp = $true} #Dynamo/DYNAMO
    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = "--enable-ethash-leak-fix"; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #ethash
    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = "--enable-ethash-leak-fix"; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #ethash
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = "--enable-ethash-leak-fix"; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD"); ExcludePoolName="Nicehash"; Algorithm = "ethash"} #ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "firepow"          ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #FiroPow/FIRO
    [PSCustomObject]@{MainAlgorithm = "heavyhash"        ;              Params = ""; Fee = 1.00;               Vendor = @("AMD")} #HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "k12"              ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD")} #kangaroo12/AEON from 2019-10-25
    [PSCustomObject]@{MainAlgorithm = "kawpow"           ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #KawPow/RVN
    [PSCustomObject]@{MainAlgorithm = "keccak"           ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD")} #keccak
    [PSCustomObject]@{MainAlgorithm = "lyra2v2_webchain" ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #Mintme.com/MINTME
    [PSCustomObject]@{MainAlgorithm = "progpow_epic"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #ProgPowEPIC/EPIC
    [PSCustomObject]@{MainAlgorithm = "progpow_sero"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #ProgPowSERO/SERO
    [PSCustomObject]@{MainAlgorithm = "progpow_veil"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #ProgPowVEIL/VEIL
    [PSCustomObject]@{MainAlgorithm = "progpow_veriblock"; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #vProgPow/VBLK
    [PSCustomObject]@{MainAlgorithm = "progpow_zano"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #ProgPowZANO/ZANO
    [PSCustomObject]@{MainAlgorithm = "sha3d"            ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #SHA3d/KCN,YCN
    [PSCustomObject]@{MainAlgorithm = "ubqhash"          ;              Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD")} #ubqhash
    #[PSCustomObject]@{MainAlgorithm = "verthash"         ;              Params = ""; Fee = 1.00;               Vendor = @("AMD")} #Verthash
    #[PSCustomObject]@{MainAlgorithm = "verushash"        ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #Verushash
    [PSCustomObject]@{MainAlgorithm = "yescrypt"         ;              Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD")} #yescrypt
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type = @("AMD")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$ValidCompute = @("GCN1","GCN2","GCN3")

foreach ($Miner_Vendor in @("AMD")) {

    $WatchdogParams = if ($Miner_Vendor -eq "AMD" -and $Session.Config.RebootOnGPUFailure -and $Session.Config.EnableRestartComputer) {" --reboot-script-gpu-watchdog '$(Join-Path $Session.MainPath "$(if ($IsLinux) {"reboot.sh"} else {"Reboot.bat"})")'"}

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Model -eq $Miner_Model -and ($Miner_Vendor -eq "CPU" -or $_.OpenCL.DeviceCapability -in $ValidCompute)}

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor -and $Device.Count} | ForEach-Object {
            $First = $true
            $Algorithm = $_.MainAlgorithm
            $Algorithm_Norm_0 = Get-Algorithm $Algorithm

            $DeviceParams = ""

            if ($Miner_Vendor -eq "CPU") {
                $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

                $DeviceParams = "$(if ($CPUThreads){" --cpu-threads $CPUThreads"})$(if ($CPUAffinity -and ($CPUThreads -le 64)){" --cpu-affinity $CPUAffinity"})"
            }

            $All_Algorithms = if ($Miner_Vendor -eq "CPU") {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")} else {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")}

		    foreach($Algorithm_Norm in $All_Algorithms) {
                if (-not $Pools.$Algorithm_Norm.Host) {continue}

                $MinMemGB = if ($_.DAG) {if ($Pools.$MainAlgorithm_Norm.DagSizeMax) {$Pools.$MainAlgorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}
                $Miner_Device = $Device | Where-Object {$Miner_Vendor -eq "CPU" -or $_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

			    if ($Miner_Device -and (-not $_.CoinSymbols -or $Pools.$Algorithm_Norm.CoinSymbol -in $_.CoinSymbols) -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.ExcludeYiimp -or -not $Session.YiimpPools.Contains("$($Pools.$Algorithm_Norm_0.Name)"))) {
                    if ($First) {
				        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
				    	$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.BusId_Type_Vendor_Index -join '!'
                        $DeviceIntensity = ($Miner_Device | % {"0"}) -join '!'
                        $First = $false
                    }

                    $Miner_Protocol = Switch ($Pools.$Algorithm_Norm.EthMode) {
                        "ethproxy"         {"--esm 0"}
                        "minerproxy"       {"--esm 1"}
						"ethstratumnh"     {""}
						default            {""}
					}

                    $Pool_Port_Index = if ($Miner_Vendor -eq "CPU") {"CPU"} else {"GPU"}
				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.$Pool_Port_Index) {$Pools.$Algorithm_Norm.Ports.$Pool_Port_Index} else {$Pools.$Algorithm_Norm.Port}

                    #--disable-extranonce-subscribe
                    #--extended-log --log-file Logs\$($_.MainAlgorithm)-$((get-date).toString("yyyyMMdd-HHmmss")).txt

                    $Miner_HR = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week
                    if ($_.MaxRejectedShareRatio) {
                        $Miner_HR *= 1-$Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Ratio_Live
                    }

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "--algorithm $(if ($_.Algorithm) {$_.Algorithm} else {$Algorithm}) --api-enable --api-port `$mport --api-rig-name $($Session.Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker) $(if ($Miner_Protocol) {"$($Miner_Protocol) "})$(if ($Miner_Vendor -eq "CPU") {"--disable-gpu$DeviceParams"} else {"--gpu-id $DeviceIDsAll --gpu-intensity $DeviceIntensity --disable-cpu $WatchdogParams"}) --pool $($Pools.$Algorithm_Norm.Host):$($Pool_Port) --wallet $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Worker) {" --worker $($Pools.$Algorithm_Norm.Worker)"})$(if ($Pools.$Algorithm_Norm.Pass) {" --password $($Pools.$Algorithm_Norm.Pass -replace "([;!])","#`$1")"}) --tls $(if ($Pools.$Algorithm_Norm.SSL) {"true"} else {"false"}) --nicehash $(if ($Pools.$Algorithm_Norm.Host -match 'NiceHash') {"true"} else {"false"}) --keepalive --retry-time 10 --disable-startup-monitor $($_.Params)" # --disable-worker-watchdog
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Miner_HR}
					    API            = "SrbMinerMulti"
					    Port           = $Miner_Port
					    Uri            = $Uri
                        FaultTolerance = $_.FaultTolerance
					    ExtendInterval = if ($_.ExtendInterval) {$_.ExtendInterval} elseif ($Miner_Vendor -eq "CPU") {2} else {$null}
                        MaxRejectedShareRatio = if ($_.MaxRejectedShareRatio) {$_.MaxRejectedShareRatio} else {$null}
                        Penalty        = 0
					    DevFee         = $_.Fee
					    ManualUri      = $ManualUri
					    EnvVars        = if ($Miner_Vendor -eq "AMD" -and $IsLinux) {@("GPU_MAX_WORKGROUP_SIZE=1024")} else {$null}
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $Algorithm_Norm_0
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                        SetLDLIBRARYPATH = $false
                        ListDevices    = "--list-devices"
                        ExcludePoolName = $_.ExcludePoolName
				    }
			    }
		    }
        }
    }
}
