using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week",
    [alias("UserName")]
    [String]$User = "",
    [String]$AECurrency = "",
    [String]$API_Key = "",
    [Bool]$EnableAPIKeyForMiners = $false
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $User -and -not $InfoOnly) {return}

$AllowZero = $true

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://prohashing.com/api/v1/status" -tag $Name -cycletime 120
}
catch {
}

if ($Pool_Request.code -ne 200) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://prohashing.com/api/v1/currencies" -tag $Name -cycletime 120
}
catch {
}

if ($PoolCoins_Request.code -ne 200) {
    Write-Log -Level Warn "Pool currencies API ($Name) has failed. "
    return
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_Coins = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Host = "mining.prohashing.com"

$Pool_Regions = @("us","eu","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currencies = @("BTC") + @($PoolCoins_Request.data.PSObject.Properties.Name | Where-Object {$_ -notmatch "_"}) | Select-Object -Unique

if ($InfoOnly) {$AECurrency = "BTC"}
elseif ($AECurrency -eq "" -or $AECurrency -notin $Pool_Currencies) {$AECurrency = $Pool_Currencies | Select-Object -First 1}

$PoolCoins_Overview = @{}
$PoolCoins_Request.data.PSObject.Properties.Value | Where-Object {$_.port -and $_.enabled -and $_.lastblock} | Group-Object -Property algo | Foreach-Object {
    $PoolCoins_Overview[$_.Name] = [PSCustomObject]@{
        "24h_blocks"  = ($_.Group."24h_blocks" | Measure-Object -Maximum).Maximum
        timesincelast = ($_.Group.timesincelast | Measure-Object -Minimum).Minimum
        workers       = ($_.Group.workers | Measure-Object -Sum).Sum
        coins         = @($_.Group.abbreviation)
    }
}

$Pool_APIKey = "$(if ($EnableAPIKeyForMiners -and $API_Key) {",k=$($API_Key)"})"

$Pool_Request.data.PSObject.Properties.Name | Where-Object {$PoolCoins_Overview.ContainsKey($_)} | ForEach-Object {
    $Pool_Port      = $Pool_Request.data.$_.port
    $Pool_Algorithm = $Pool_Request.data.$_.name
    $Pool_PoolFee   = [double]$Pool_Request.data.$_.pps_fee * 100
    $Pool_Factor    = [double]$Pool_Request.data.$_.mbtc_mh_factor
    $Pool_TSL       = [int]$PoolCoins_Overview[$_].timesincelast
    $Pool_BLK       = [int]$PoolCoins_Overview[$_]."24h_blocks"
    $Pool_Workers   = [int]$PoolCoins_Overview[$_].workers
    $Pool_CoinSymbol = if ($PoolCoins_Overview[$_].Coins.Count -eq 1) {$PoolCoins_Overview[$_].Coins[0]} else {$null}

    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    if ($Pool_Algorithm -in @("ethash","kawpow") -and $Pool_CoinSymbol) {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm -CoinSymbol $Pool_CoinSymbol
    } else {
        if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
        $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    }

    if (-not $InfoOnly -and (($Algorithm -and $Pool_Algorithm_Norm -notin $Algorithm) -or ($ExcludeAlgorithm -and $Pool_Algorithm_Norm -in $ExcludeAlgorithm))) {return}
    if (-not $InfoOnly -and $Pool_CoinSymbol -and (($CoinSymbol -and $Pool_CoinSymbol -notin $CoinSymbol) -or ($ExcludeCoinSymbol -and $Pool_CoinSymbol -in $ExcludeCoinSymbol))) {return}

    $Pool_DagSizeMax = $Pool_CoinSymbolMax = $null
    if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {
        if ($Pool_CoinSymbol) {
            $Pool_DagSizeMax = Get-EthDAGSize -Algorithm $Pool_Algorithm_Norm -CoinSymbol $Pool_CoinSymbol
            $Pool_CoinSymbolMax = $Pool_CoinSymbol
        } else {
            $pmax = Get-EthDAGSizeMax -CoinSymbols $PoolCoins_Overview[$_].Coins -Algorithm $Pool_Algorithm_Norm
            if ($pmax.CoinSymbol -and $Pool_Algorithm -in @("ethash","kawpow")) {
                $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm -CoinSymbol $pmax.CoinSymbol
            }
            $Pool_CoinSymbolMax = $pmax.CoinSymbol
            $Pool_DagSizeMax    = $pmax.DagSize
        }
    }

    $Pool_MemorySize = "$(if ($Pool_Algorithm_Norm -eq "EthashLowMemory") {",l=`$memsizegb"})"
    
    if (-not $InfoOnly) {
        $NewStat = -not (Test-Path "Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")
        $Pool_Price = [double]$Pool_Request.data.$_."estimate_$(if ($NewStat) {"last24h"} else {"current"})"  / $Pool_Factor
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $(-not $NewStat) -HashRate $Pool_Request.data.$_.hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $Pool_Regions) {
        $Pool_Params = if ($Params.$AECurrency) {
            $Pool_ParamsCurrency = "$(if ($Pool_APIKey) {$Params.$AECurrency -replace "k=[0-9a-f]+" -replace ",+","," -replace "^,+" -replace ",+$"} else {$Params.$AECurrency})"
            if ($Pool_ParamsCurrency) {",$($Pool_ParamsCurrency)"}
        }
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = ""
            CoinSymbol    = ""
            Currency      = $AECurrency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.$StatAverageStable
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = "$($Pool_Region).$($Pool_Host)"
            Port          = $Pool_Port
            User          = $User
            Pass          = "a=$($_),n={workername:$Worker}{diff:,d=`$difficulty}$($Pool_MemorySize)$($Pool_APIKey)$($Pool_Params)"
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
            PaysLive      = $true
            DataWindow    = $DataWindow
            Hashrate      = $Stat.HashRate_Live
            Workers       = $Pool_Workers
            BLK           = $Stat.BlockRate_Average
            TSL           = $Pool_TSL
            CoinSymbolMax = $Pool_CoinSymbol
            DagSizeMax    = $Pool_DagSizeMax
			ErrorRatio    = $Stat.ErrorRatio
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_0       = 0.0
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $User
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}
