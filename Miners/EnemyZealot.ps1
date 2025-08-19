using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://github.com/z-enemy/z-enemy/releases"
$Port = "302{0:d2}"
$DevFee = 1.0
$Version = "2.6.2"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-enemyz\z-enemy"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.6.2-zenemy/z-enemy-2.6.2-cuda101-libcurl4.tar.gz"
            Cuda = "10.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.6.2-zenemy/z-enemy-2.6.2-cuda100-libcurl4.tar.gz"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.6.2-zenemy/z-enemy-2.6.2-cuda92-libcurl4.tar.gz"
            Cuda = "9.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.6.2-zenemy/z-enemy-2.6.2-cuda91.tar.gz"
            Cuda = "9.1"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-enemyz\z-enemy.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.6.3-zenemy/z-enemy-2.6.3-win-cuda11.1.zip"
            Cuda = "11.1"
            Version = "2.6.3"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.6.2-zenemy/z-enemy-2.6.2-win-cuda10.1.zip"
            Cuda = "10.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.6.2-zenemy/z-enemy-2.6.2-win-cuda10.0.zip"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.6.2-zenemy/z-enemy-2.6.2-win-cuda9.2.zip"
            Cuda = "9.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.6.2-zenemy/z-enemy-2.6.2-win-cuda9.1.zip"
            Cuda = "9.1"
        }
    )
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo"; Params = "-N 1"} #AeriumX, new in 1.11
    #[PSCustomObject]@{MainAlgorithm = "bcd"; Params = "-N 1"} #Bcd, new in 1.20
    #[PSCustomObject]@{MainAlgorithm = "bitcore"; Params = "-N 1"} #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = "-N 1"} # New in 1.11
    [PSCustomObject]@{MainAlgorithm = "hex"; Params = "-N 1"; ExtendInterval = 3; FaultTolerance = 0.5; HashrateDuration = "Day"} #HEX/XDNA, new in 1.15a
    #[PSCustomObject]@{MainAlgorithm = "hsr"; Params = "-N 1"} #HSR
    [PSCustomObject]@{MainAlgorithm = "kawpow"; DAG = $true; Params = "-N 1"; ExtendInterval = 3; MinMemGB=3; ExcludePoolName = "MiningRigRentals"} #KawPOW/RVN, new in 2.5
    [PSCustomObject]@{MainAlgorithm = "kawpow2g"; DAG = $true; Params = "-N 1"; ExtendInterval = 3; MinMemGB=3; ExcludePoolName = "MiningRigRentals";Algorithm = "kawpow"} #KawPOW/RVN, new in 2.5
    [PSCustomObject]@{MainAlgorithm = "kawpow3g"; DAG = $true; Params = "-N 1"; ExtendInterval = 3; MinMemGB=3; ExcludePoolName = "MiningRigRentals";Algorithm = "kawpow"} #KawPOW/RVN, new in 2.5
    [PSCustomObject]@{MainAlgorithm = "kawpow4g"; DAG = $true; Params = "-N 1"; ExtendInterval = 3; MinMemGB=3; ExcludePoolName = "MiningRigRentals";Algorithm = "kawpow"} #KawPOW/RVN, new in 2.5
    [PSCustomObject]@{MainAlgorithm = "kawpow5g"; DAG = $true; Params = "-N 1"; ExtendInterval = 3; MinMemGB=3; ExcludePoolName = "MiningRigRentals";Algorithm = "kawpow"} #KawPOW/RVN, new in 2.5
    #[PSCustomObject]@{MainAlgorithm = "phi"; Params = "-N 1"; ExtendInterval = 2} #PHI
    #[PSCustomObject]@{MainAlgorithm = "phi2"; Params = "-N 1"} #PHI2, new in 1.12
    #[PSCustomObject]@{MainAlgorithm = "poly"; Params = "-N 1"} #Polytimos
    #[PSCustomObject]@{MainAlgorithm = "skunk"; Params = "-N 1"} #Skunk, new in 1.11
    #[PSCustomObject]@{MainAlgorithm = "sonoa"; Params = "-N 1"} #Sonoa, new in 1.12 (testing)
    #[PSCustomObject]@{MainAlgorithm = "timetravel"; Params = "-N 1"} #Timetravel8
    #[PSCustomObject]@{MainAlgorithm = "tribus"; Params = "-N 1"} #Tribus, new in 1.10
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = "-N 10"; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16R
    #[PSCustomObject]@{MainAlgorithm = "x16rv2"; Params = "-N 10"; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16Rv2
    #[PSCustomObject]@{MainAlgorithm = "x16s"; Params = "-N 1"; FaultTolerance = 0.5} #X16S (T-Rex faster)
    #[PSCustomObject]@{MainAlgorithm = "x17"; Params = "-N 1"} #X17 (T-Rex has better numbers at the pool)
    [PSCustomObject]@{MainAlgorithm = "xevan"; Params = "-N 1"} #Xevan, new in 1.09a
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $UriCuda.Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Cuda = $null
for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri  = $UriCuda[$i].Uri
        $Cuda = $UriCuda[$i].Cuda
        if ($UriCuda[$i].Version) {$Version = $UriCuda[$i].Version}
    }
}

if (-not $Cuda) {return}

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object {$_.Model -eq $Miner_Model}

    $Miner_AllowAmpere = (Compare-Version $Version "2.6.3") -ge 0

    $Commands | Foreach-Object {
        $First = $true

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        
        $MainAlgorithm_0 = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
            if (-not $Pools.$Algorithm_Norm.Host) {continue}

            $MinMemGB = if ($_.DAG) {if ($Pools.$Algorithm_Norm.DagSizeMax) {$Pools.$Algorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}
            $Miner_Device = $Device | Where-Object {(Test-VRAM $_ $MinMemGb) -and ($Miner_AllowAmpere -or $_.OpenCL.Architecture -ne "Ampere")}

			if ($Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-R 1 --api-bind=0 --api-bind-http=`$mport -d $($DeviceIDsAll) -a $($MainAlgorithm_0) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($Pools.$Algorithm_Norm.Failover | Select-Object | Foreach-Object {" -o $($_.Protocol)://$($_.Host):$($_.Port) -u $($_.User)$(if ($_.Pass) {" -p $($_.Pass)"})"}) --no-cert-verify $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
					API            = "EnemyZ"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = if ($_.ExtendInterval) {$_.ExtendInterval} else {2}
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                    ExcludePoolName = $_.ExcludePoolName
				}
			}
		}
    }
}
