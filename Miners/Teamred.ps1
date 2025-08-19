using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Port = "409{0:d2}"
$ManualUri = "https://bitcointalk.org/index.php?topic=5059817.0"
$DevFee = 3.0
$Version = "0.10.21"

if ($IsLinux) {
    $Path = ".\Bin\AMD-Teamred\teamredminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.10.21-teamred/teamredminer-v0.10.21-linux.tgz"
    $DatFile = "$env:HOME/.vertcoin/verthash.dat"
} else {
    $Path = ".\Bin\AMD-Teamred\teamredminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.10.21-teamred/teamredminer-v0.10.21-win.zip"
    $DatFile = "$env:APPDATA\Vertcoin\verthash.dat"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "abel";             DAG = $true; MinMemGb = 5;   Params = ""; DevFee = 1.0;  ExtendInterval = 3; MainAlgorithmXlat = "Abelian"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "alph";                          MinMemGb = 1.5; Params = ""; DevFee = 1.0;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "autolykos2";       DAG = $true; MinMemGb = 1.5; Params = ""; DevFee = 2.0;  ExtendInterval = 2; ExcludeCompute = @("GCN1","GCN2")} #Autolykos2/ERGO
    [PSCustomObject]@{MainAlgorithm = "cn_conceal";                    MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cn_haven";                      MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cn_heavy";                      MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cn_saber";                      MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cnr";                           MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cnv8";                          MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cnv8_dbl";                      MinMemGb = 3.3; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cnv8_half";                     MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cnv8_rwz";                      MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cnv8_trtl";                     MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cnv8_upx2";                     MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cuckarood29_grin";              MinMemGb = 6;   Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "cuckatoo31_grin";               MinMemGb = 8;   Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "etchash";          DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 1;   Params = ""; DevFee = 0.75; ExtendInterval = 3; MainAlgorithmXlat = "ethash2g"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; MainAlgorithmXlat = "ethash3g"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 0.75; ExtendInterval = 3; MainAlgorithmXlat = "ethash4g"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 4;   Params = ""; DevFee = 0.75; ExtendInterval = 3; MainAlgorithmXlat = "ethash5g"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; MainAlgorithmXlat = "ethashlowmemory"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "firopow";          DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 2.0;  ExtendInterval = 3; ExcludeCompute = @("GCN1","GCN2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "fishhash";         DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 2.0;  ExtendInterval = 3; ExcludeCompute = @("GCN1","GCN2","GCN3","GCN4","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "karlsen";                       MinMemGb = 1.5; Params = ""; DevFee = 1.0;  ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "kas";                           MinMemGb = 1.5; Params = ""; DevFee = 1.0;  MainAlgorithmXlat = "kHeavyHash"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "kawpow";           DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 2.0;  ExtendInterval = 3; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "kawpow";           DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 2.0;  ExtendInterval = 3; MainAlgorithmXlat = "kawpow2g"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "kawpow";           DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 2.0;  ExtendInterval = 3; MainAlgorithmXlat = "kawpow3g"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "kawpow";           DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 2.0;  ExtendInterval = 3; MainAlgorithmXlat = "kawpow4g"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "kawpow";           DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 2.0;  ExtendInterval = 3; MainAlgorithmXlat = "kawpow5g"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3";                     MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "lyra2z";                        MinMemGb = 1.5; Params = ""; DevFee = 3.0;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "mtp";                           MinMemGb = 5;   Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "nimiq";                         MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "phi2";                          MinMemGb = 1.5; Params = ""; DevFee = 3.0;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "pyrin";                         MinMemGb = 1.5; Params = ""; DevFee = 1.0;  MainAlgorithmXlat = "HeavyHashPyrin"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ton";                           MinMemGb = 1.5; Params = ""; DevFee = 3.0;  MainAlgorithmXlat = "SHA256ton"; ExtendInterval = 2; ExcludeCompute = @("GCN1","GCN2"); PoolName = "hashrate|toncoinpool|ton-pool|whalestonpool"}
    [PSCustomObject]@{MainAlgorithm = "trtl_chukwa";                   MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "verthash";                      MinMemGb = 1.5; Params = ""; DevFee = 2.0;  ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "trtl_chukwa2";                  MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "x16r";                          MinMemGb = 3.3; Params = ""; DevFee = 2.5;  ExtendInterval = 2; ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "x16rt";                         MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExtendInterval = 2; ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "x16rv2";                        MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExtendInterval = 2; ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}
    [PSCustomObject]@{MainAlgorithm = "x16s";                          MinMemGb = 1.5; Params = ""; DevFee = 2.5;  ExcludeCompute = @("GCN1","GCN2","RDNA1","RDNA2","RDNA3")}

    # Dual mining Abelian
    [PSCustomObject]@{MainAlgorithm = "abel";             DAG = $true; MinMemGb = 5;   Params = ""; DevFee = 1.0; ExtendInterval = 3; MainAlgorithmXlat = "Abelian"; ExcludeCompute = @("GCN1","GCN2"); SecondaryAlgorithm = "alph"} #Abelian/ABEL + ALPH
    [PSCustomObject]@{MainAlgorithm = "abel";             DAG = $true; MinMemGb = 5;   Params = ""; DevFee = 1.0; ExtendInterval = 3; MainAlgorithmXlat = "Abelian"; ExcludeCompute = @("GCN1","GCN2"); SecondaryAlgorithm = "karlsen"; SecondAlgorithmXlat = "KarlsenHash"} #Abelian/ABEL + KLS
    [PSCustomObject]@{MainAlgorithm = "abel";             DAG = $true; MinMemGb = 5;   Params = ""; DevFee = 1.0; ExtendInterval = 3; MainAlgorithmXlat = "Abelian"; ExcludeCompute = @("GCN1","GCN2"); SecondaryAlgorithm = "kas";     SecondAlgorithmXlat = "kHeavyHash"} #Abelian/ABEL + KAS
    [PSCustomObject]@{MainAlgorithm = "abel";             DAG = $true; MinMemGb = 5;   Params = ""; DevFee = 1.0; ExtendInterval = 3; MainAlgorithmXlat = "Abelian"; ExcludeCompute = @("GCN1","GCN2"); SecondaryAlgorithm = "pyrin";   SecondAlgorithmXlat = "PyrinHash"} #Abelian/ABEL + PYI
    [PSCustomObject]@{MainAlgorithm = "abel";             DAG = $true; MinMemGb = 5;   Params = ""; DevFee = 1.0; ExtendInterval = 3; MainAlgorithmXlat = "Abelian"; ExcludeCompute = @("GCN1","GCN2"); SecondaryAlgorithm = "ton";     SecondAlgorithmXlat = "SHA256ton"} #Abelian/ABEL + GRAM

    # Dual mining ERG + kHeavyHash/KASPA
    [PSCustomObject]@{MainAlgorithm = "autolykos2";       DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; SecondAlgorithm = "alph"}
    [PSCustomObject]@{MainAlgorithm = "autolykos2";       DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; SecondAlgorithm = "kas"; SecondAlgorithmXlat = "kHeavyHash"}
    [PSCustomObject]@{MainAlgorithm = "autolykos2";       DAG = $true; MinMemGb = 5;   Params = ""; DevFee = 0-75; ExtendInterval = 3; SecondAlgorithm = "ton"; SecondAlgorithmXlat = "SHA256ton" }

    # Dual mining Ethash + kHeavyHash/KASPA
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; SecondAlgorithm = "alph"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; SecondAlgorithm = "kas"; SecondAlgorithmXlat = "kHeavyHash"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 1;   Params = ""; DevFee = 0.75; ExtendInterval = 3; MainAlgorithmXlat = "ethash2g"; SecondAlgorithm = "kas"; SecondAlgorithmXlat = "kHeavyHash"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; MainAlgorithmXlat = "ethash3g"; SecondAlgorithm = "kas"; SecondAlgorithmXlat = "kHeavyHash"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 0.75; ExtendInterval = 3; MainAlgorithmXlat = "ethash3g"; SecondAlgorithm = "kas"; SecondAlgorithmXlat = "kHeavyHash"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 4;   Params = ""; DevFee = 0.75; ExtendInterval = 3; MainAlgorithmXlat = "ethash4g"; SecondAlgorithm = "kas"; SecondAlgorithmXlat = "kHeavyHash"; ExcludeCompute = @("GCN1","GCN2")}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; MainAlgorithmXlat = "ethashlowmemory"; SecondAlgorithm = "kas"; SecondAlgorithmXlat = "kHeavyHash"; ExcludeCompute = @("GCN1","GCN2")}

    #[PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; SecondAlgorithm = "ton"; SecondPoolName = "hashrate|toncoinpool|ton-pool|whalestonpool"}
    #[PSCustomObject]@{MainAlgorithm = "ethashlowmemory";  DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; SecondAlgorithm = "ton"; SecondPoolName = "hashrate|toncoinpool|ton-pool|whalestonpool"}
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
        Name      = $Name
        Path      = $Path
        Port      = $Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

if (-not (Test-Path $DatFile) -or (Get-Item $DatFile).length -lt 1.19GB) {
    $DatFile = Join-Path $Session.MainPath "Bin\Common\verthash.dat"
}

$Global:DeviceCache.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object {$_.Model -eq $Miner_Model}

    $Miner_PlatformId = $Device | Select -Property Platformid -Unique -ExpandProperty PlatformId

    $Commands | ForEach-Object {
        $First = $True

        $MainAlgorithm = if ($_.MainAlgorithmXlat) {$_.MainAlgorithmXlat} else {$_.MainAlgorithm}
        $SecondAlgorithm = if ($_.SecondAlgorithmXlat) {$_.SecondAlgorithmXlat} else {$_.SecondAlgorithm}

        $MainAlgorithm_Norm_0 = Get-Algorithm $MainAlgorithm
        $SecondAlgorithm_Norm_0 = if ($SecondAlgorithm) {Get-Algorithm $SecondAlgorithm} else {$null}

        $Miner_ExcludeCompute = $_.ExcludeCompute
        $Miner_Compute = $_.Compute

		foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
            if (-not $Pools.$MainAlgorithm_Norm.Host) {continue}

            $MinMemGB = if ($_.DAG) {if ($Pools.$MainAlgorithm_Norm.DagSizeMax) {$Pools.$MainAlgorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}
            #Zombie-mode since v0.7.14
            if ($_.DAG -and $MainAlgorithm_Norm_0 -match $Global:RegexAlgoIsEthash -and $MinMemGB -gt $_.MinMemGB -and $Session.Config.EnableEthashZombieMode) {
                $MinMemGB = $_.MinMemGB
            }
            $Miner_Device = $Device | Where-Object {(Test-VRAM $_ $MinMemGB) -and (-not $Miner_ExcludeCompute -or $_.OpenCL.DeviceCapability -notin $Miner_ExcludeCompute) -and (-not $Miner_Compute -or $_.OpenCL.DeviceCapability -in $Miner_Compute)}
            $Miner_Device_Dual = if ($SecondAlgorithm_Norm_0) {$Miner_Device | Where-Object {-not $Miner_Compute -or $_.OpenCL.DeviceCapability -in $Miner_Compute}}

            if ($SecondAlgorithm_Norm_0 -and $Miner_Compute -and (-not ($Miner_Device_Dual | Measure-Object).Count)) {
                $Miner_Device = $null
            } else {
                $Miner_DevFee = $_.DevFee

                if ($_.MainAlgorithm -match "^ethash" -and (($Miner_Model -split '-') -notmatch "(Baffin|Ellesmere|RX\d)" | Measure-Object).Count) {
                    $Miner_DevFee = 1.0
                } elseif ($_.MainAlgorithm -eq "abel") {
                    $Device_Capabilities = @($Miner_Device | Foreach-Object {$_.OpenCL.DeviceCapability} | Select-Object -Unique)
                    if (Compare-Object $Device_Capabilities @("GCN50","RDNA1") -ExcludeDifferent -IncludeEqual) {
                        $Miner_DevFee = 2.0
                    } elseif (Compare-Object $Device_Capabilities @("GCN51","CDNA1") -ExcludeDifferent -IncludeEqual) {
                        $Miner_DevFee = 3.0
                    }
                }
            }

			if ($Miner_Device -and
                (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and
                (-not $_.PoolName -or $Pools.$MainAlgorithm_Norm.Host -match $_.PoolName)) {
                if ($First) {
				    $Miner_Port = $Port -f (2 * ($Miner_Device | Select-Object -First 1 -ExpandProperty Index))
					$Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll  = $Miner_Device.BusId_Type_Vendor_Index -join ','
                    $DeviceIDsDual = if ($SecondAlgorithm_Norm_0) {$Miner_Device_Dual.BusId_Type_Vendor_Index -join ','}
                    $First = $False
                }

                $Pool_User = $Pools.$MainAlgorithm_Norm.User
                $Pool_Protocol = if ($Pools.$MainAlgorithm_Norm.Protocol -eq "wss") {"stratum+tcp"} else {$Pools.$MainAlgorithm_Norm.Protocol}
                $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                $Pool_Host = if ($Pool_Port) {if ($Pools.$MainAlgorithm_Norm.Host -match "^([^/]+)/(.+)$") {"$($Matches[1]):$($Pool_Port)/$($Matches[2])"} else {"$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port)"}} else {$Pools.$MainAlgorithm_Norm.Host}

                $IsVerthash = $MainAlgorithm_Norm_0 -eq "Verthash"

                [System.Collections.Generic.List[string]]$AdditionalParams = @("--watchdog_disabled")
                if ($Pools.$MainAlgorithm_Norm.Host -match "bsod" -and $MainAlgorithm_Norm_0 -eq "x16rt") {
                    [void]$AdditionalParams.Add("--no_ntime_roll")
                }
                if ($IsLinux -and $MainAlgorithm_Norm_0 -match "^cn") {
                    [void]$AdditionalParams.Add("--allow_large_alloc")
                }
                if ($_.MainAlgorithm -eq "nimiq") {
                    $Pool_User = $Pools.$MainAlgorithm_Norm.Wallet
                    $Pool_Protocol = "stratum+tcp"
                    [void]$AdditionalParams.Add("--nimiq_worker=$($Pools.$MainAlgorithm_Norm.Worker)")
                    #if ($Pools.$MainAlgorithm_Norm_0.Name -match "Icemining") {
                    #    $Pool_Host = $Pool_Host -replace "^nimiq","nimiq-trm"
                    #}
                } elseif ($IsVerthash) {
                    [void]$AdditionalParams.Add("--verthash_file='$($DatFile)'")
                }

                if ($SecondAlgorithm_Norm_0) {

                    $Miner_Intensity = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)".Intensity

                    if (-not $Miner_Intensity) {$Miner_Intensity = 0}

                    foreach($Intensity in @($Miner_Intensity)) {

                        $Intensity = try {[double]$Intensity} catch {0}

                        if ($Intensity -gt 0) {
                            $Miner_Name_Dual = (@($Name) + @("$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)-$([int]($Intensity*100))") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                            $DeviceIntensitiesAll = (",$($Intensity)"*($Miner_Device | Measure-Object).Count) -replace "^,"
                        } else {
                            $Miner_Name_Dual = $Miner_Name
                            $DeviceIntensitiesAll = $null
                        }

                        foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                            if ($Pools.$SecondAlgorithm_Norm.Host -and
                                (-not $_.SecondExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.SecondExcludePoolName) -and
                                (-not $_.SecondPoolName -or $Pools.$SecondAlgorithm_Norm.Host -match $_.SecondPoolName)) {

                                $TonMode = if ($SecondAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$SecondAlgorithm_Norm.EthMode) {$Pools.$SecondAlgorithm_Norm.EthMode} else {$null}

                                $SecondPool_Protocol  = if ($Pools.$SecondAlgorithm_Norm.Protocol -eq "wss") {"stratum+tcp"} else {$Pools.$SecondAlgorithm_Norm.Protocol}
                                if ($SecondPool_Protocol -eq "") {$SecondPool_Protocol = "stratum+$(if ($Pools.$SecondAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                $SecondPool_Port      = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
                                $SecondPool_Host      = if ($SecondPool_Port) {if ($Pools.$SecondAlgorithm_Norm.Host -match "^([^/]+)/(.+)$") {"$($Matches[1]):$($SecondPool_Port)/$($Matches[2])"} else {"$($Pools.$SecondAlgorithm_Norm.Host):$($SecondPool_Port)"}} else {$Pools.$SecondAlgorithm_Norm.Host}
                                $SecondPool_Arguments = "--$($_.SecondAlgorithm) -d $($DeviceIDsDual) -o $($SecondPool_Protocol)://$($SecondPool_Host) -u $($Pools.$SecondAlgorithm_Norm.Wallet).$($Pools.$SecondAlgorithm_Norm.Worker)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" -p $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($TonMode) {" --ton_pool_mode=$($TonMode)"}) --api2_listen=`$mport2 --$($_.SecondAlgorithm)_end"

				                [PSCustomObject]@{
					                Name           = $Miner_Name_Dual
					                DeviceName     = $Miner_Device.Name
					                DeviceModel    = $Miner_Model
					                Path           = $Path
					                Arguments      = "-a $($_.MainAlgorithm) -d $($DeviceIDsAll) -o $($Pool_Protocol)://$($Pool_Host) -u $($Pool_User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($Pools.$MainAlgorithm_Norm.Pass)"}) $($SecondPool_Arguments)$(if ($DeviceIntensitiesAll) {"  --dual_intensity=$($DeviceIntensitiesAll)"}) --api_listen=`$mport --bus_reorder $(if ($AdditionalParams.Count) {$AdditionalParams -join " "}) $($_.Params)"
					                HashRates      = [PSCustomObject]@{
                                                        $MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week
                                                        $SecondAlgorithm_Norm = $Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week
                                                     }
					                API            = "Xgminer"
					                Port           = $Miner_Port
					                Uri            = $Uri
                                    FaultTolerance = $_.FaultTolerance
					                ExtendInterval = $_.ExtendInterval
                                    Penalty        = 0
					                DevFee         = [PSCustomObject]@{
                                                        $MainAlgorithm_Norm = $Miner_DevFee
                                                        $SecondAlgorithm_Norm = 0
                                                     }
					                ManualUri      = $ManualUri
                                    Version        = $Version
                                    PowerDraw      = 0
                                    BaseName       = $Name
                                    BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)"
                                    Benchmarked    = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                    LogFile        = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                    PrerequisitePath = if ($IsVerthash) {$DatFile} else {$null}
                                    PrerequisiteURI  = "$(if ($IsVerthash) {"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-verthash/verthash.dat"})"
                                    PrerequisiteMsg  = "$(if ($IsVerthash) {"Downloading verthash.dat (1.2GB) in the background, please wait!"})"
                                    ExcludePoolName = $_.ExcludePoolName
				                }
                            }
                        }
                    }

                } else {

                    $TonMode = if ($MainAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$MainAlgorithm_Norm.EthMode) {$Pools.$MainAlgorithm_Norm.EthMode} else {$null}

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "-a $($_.MainAlgorithm) -d $($DeviceIDsAll) -o $($Pool_Protocol)://$($Pool_Host) -u $($Pool_User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($TonMode) {" --ton_pool_mode=$($TonMode)"}) --api_listen=`$mport --bus_reorder $(if ($AdditionalParams.Count) {$AdditionalParams -join " "}) $($_.Params)"
					    HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week}
					    API            = "Xgminer"
					    Port           = $Miner_Port
					    Uri            = $Uri
                        FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
					    DevFee         = $Miner_DevFee
					    ManualUri      = $ManualUri
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $MainAlgorithm_Norm_0
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                        PrerequisitePath = if ($IsVerthash) {$DatFile} else {$null}
                        PrerequisiteURI  = "$(if ($IsVerthash) {"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-verthash/verthash.dat"})"
                        PrerequisiteMsg  = "$(if ($IsVerthash) {"Downloading verthash.dat (1.2GB) in the background, please wait!"})"
                        ListDevices    = "--list_devices"
                        ExcludePoolName = $_.ExcludePoolName
				    }
                }
			}
		}
    }
}
