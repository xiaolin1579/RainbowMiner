using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD, NVIDIA present in system

$ManualUri = "https://github.com/develsoftware/GMinerRelease/releases"
$Port = "346{0:d2}"
$DevFee = 2.0
$Cuda = "9.0"
$Version = "2.75"
$DeviceCapability = "5.0"
$EnableContest = $false

if ($IsLinux) {
    $Path = ".\Bin\GPU-Gminer275\miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.75-gminer/gminer_2_75_linux64.tar.xz"
} else {
    $Path = ".\Bin\GPU-Gminer275\miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.75-gminer/gminer_2_75_windows64.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Equihash24x7";                 MinMemGb = 3.0;                   Params = "--algo 192_7";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; AutoPers = $true} #Equihash 192,7
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
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

$ContestWallet = if ($EnableContest) {if ($Session.Config.Coins.ETH.Wallet -match "^0x[0-9a-f]{40}$") {$Session.Config.Coins.ETH.Wallet} else {"0xaaD1d2972f99A99248464cdb075B28697d4d8EEd"}}

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object {$_.Model -eq $Miner_Model -and ($Miner_Vendor -ne "NVIDIA" -or -not $_.OpenCL.DeviceCapability -or (Compare-Version $_.OpenCL.DeviceCapability $DeviceCapability) -ge 0)}

        if (-not $Device) {return}

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor -and (-not $_.Version -or [version]$_.Version -le [version]$Version)} | ForEach-Object {
            $First = $true
            
            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $SecondAlgorithm_Norm = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $HasEthproxy = $MainAlgorithm_Norm_0 -match $Global:RegexAlgoHasEthproxy

            $DualIntensity = $_.Intensity

            if ($SecondAlgorithm_Norm) {
                $Miner_Config = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)".Intensity
                if ($Miner_Config -and $Miner_Config -notcontains $DualIntensity) {$Miner_Device = $null}
            }

		    foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
                if (-not $Pools.$MainAlgorithm_Norm.Host) {continue}

                $MinMemGB = if ($_.DAG) {if ($Pools.$MainAlgorithm_Norm.DagSizeMax) {$Pools.$MainAlgorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}
                $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

			    if ($Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbol -or $_.CoinSymbol -icontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol -or $_.ExcludeCoinSymbol -inotcontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and (-not $SecondAlgorithm_Norm -or ($Pools.$SecondAlgorithm_Norm.Host -and (-not $_.ExcludePoolName2 -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName2) -and (-not $_.CoinSymbol2 -or $_.CoinSymbol2 -icontains $Pools.$SecondAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol2 -or $_.ExcludeCoinSymbol2 -inotcontains $Pools.$SecondAlgorithm_Norm.CoinSymbol)))) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)$(if ($DualIntensity -ne $null) {"-$($DualIntensity)"})"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.BusId_Type_Vendor_Index -join ' '
                        if ($_.Intensity -ne $null) {
                            $DeviceIntensitiesAll = " $($DualIntensity)"*($Miner_Device | Measure-Object).Count
                        }
                        $First = $false
                    }
                    $PersCoin = if ($MainAlgorithm_Norm -match "^Equihash") {Get-EquihashCoinPers $Pools.$MainAlgorithm_Norm.CoinSymbol -Default "auto"}
				    $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                    if ($SecondAlgorithm_Norm) {
                        $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
				        [PSCustomObject]@{
					        Name           = $Miner_Name
					        DeviceName     = $Miner_Device.Name
					        DeviceModel    = $Miner_Model
					        Path           = $Path
					        Arguments      = "--api `$mport --devices $($DeviceIDsAll)$(if ($DualIntensity -ne $null) {" --dual_intensity$($DeviceIntensitiesAll)"}) --server $($Pools.$MainAlgorithm_Norm.Host) --port $($Pool_Port)$(if ($HasEthproxy -and $Pools.$MainAlgorithm_Norm.EthMode -ne $null -and $Pools.$MainAlgorithm_Norm.EthMode -notin @("ethproxy","qtminer")) {" --proto stratum"}) --user $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers $($PersCoin)"})$(if ($Pools.$MainAlgorithm_Norm.SSL) {" --ssl 1 --ssl_verification 0"}) --cuda $([int]($Miner_Vendor -eq "NVIDIA")) --opencl $([int]($Miner_Vendor -eq "AMD")) --dserver $($Pools.$SecondAlgorithm_Norm.Host) --dport $($SecondPool_Port) --duser $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --dpass $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($Pools.$SecondAlgorithm_Norm.SSL) {" --dssl 1"})$(if ($ContestWallet) {" --contest_wallet $($ContestWallet)"}) --watchdog 0 --pec 0 --nvml 1 $($_.Params)"
					        HashRates      = [PSCustomObject]@{
                                                $MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                $SecondAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($SecondAlgorithm_Norm)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                            }
					        API            = "Gminer"
					        Port           = $Miner_Port
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
					        DevFee         = [PSCustomObject]@{
								                ($MainAlgorithm_Norm) = if ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
								                ($SecondAlgorithm_Norm) = 0
                                              }
					        Uri            = $Uri
					        ManualUri      = $ManualUri
					        NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)"
                            Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            ExcludePoolName= $_.ExcludePoolName
				        }
                    } else {
				        [PSCustomObject]@{
					        Name           = $Miner_Name
					        DeviceName     = $Miner_Device.Name
					        DeviceModel    = $Miner_Model
					        Path           = $Path
					        Arguments      = "--api `$mport --devices $($DeviceIDsAll) --server $($Pools.$MainAlgorithm_Norm.Host) --port $($Pool_Port)$(if ($HasEthproxy -and $Pools.$MainAlgorithm_Norm.EthMode -ne $null -and $Pools.$MainAlgorithm_Norm.EthMode -notin @("ethproxy","qtminer")) {" --proto stratum"}) --user $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers $($PersCoin)"})$(if ($Pools.$MainAlgorithm_Norm.SSL) {" --ssl 1 --ssl_verification 0"}) --cuda $([int]($Miner_Vendor -eq "NVIDIA")) --opencl $([int]($Miner_Vendor -eq "AMD"))$(if ($ContestWallet) {" --contest_wallet $($ContestWallet)"}) --watchdog 0 --pec 0 --nvml 1 $($_.Params)"
					        HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))}
					        API            = "Gminer"
					        Port           = $Miner_Port
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
					        DevFee         = if ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
					        Uri            = $Uri
					        ManualUri      = $ManualUri
					        NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $MainAlgorithm_Norm_0
                            Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            ExcludePoolName= $_.ExcludePoolName
				        }
                    }
			    }
		    }
        }
    }
}
