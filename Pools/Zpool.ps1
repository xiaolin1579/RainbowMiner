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
    [String]$AECurrency = ""
)

$CoinSymbol = $Session.Config.Pools.$Name.CoinSymbol
$ExcludeCoinSymbol = $Session.Config.Pools.$Name.ExcludeCoinSymbol

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.zpool.ca/api/status" -tag $Name -cycletime 120 -delay 750 -timeout 30
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://www.zpool.ca/api/currencies" -tag $Name -cycletime 120 -delay 750 -timeout 30
}
catch {
    Write-Log -Level Warn "Pool currencies API ($Name) has failed. "
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_Coins = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("na","eu","sea","jp")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Currencies = @("BTC","DOGE") + @($PoolCoins_Request.PSObject.Properties | Where-Object {$_.Value.conversion_disabled -ne "1"} | Foreach-Object {if ($_.Value.symbol -eq $null){$_.Name} else {$_.Value.symbol}} | Select-Object -Unique) | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}
if ($PoolCoins_Request) {
    $PoolCoins_Algorithms = @($Pool_Request.PSObject.Properties.Value | Where-Object coins -eq 1 | Select-Object -ExpandProperty name -Unique)
    if ($PoolCoins_Algorithms.Count) {foreach($p in $PoolCoins_Request.PSObject.Properties.Name) {if ($PoolCoins_Algorithms -contains $PoolCoins_Request.$p.algo) {$Pool_Coins[$PoolCoins_Request.$p.algo] = [hashtable]@{Name = $PoolCoins_Request.$p.name; Symbol = $p -replace '-.+$'}}}}
}

if (-not $InfoOnly -and $Pool_Currencies.Count -ge 1) {
    if ($AECurrency -eq "" -or $AECurrency -notin $Pool_Currencies) {$AECurrency = $Pool_Currencies | Select-Object -First 1}
    $Pool_Currencies = $Pool_Currencies | Where-Object {$_ -eq $AECurrency}
}

$Pool_Request.PSObject.Properties.Name | ForEach-Object {
    $Pool_Algorithm  = $Pool_Request.$_.name
    $Pool_Host       = "mine.zpool.ca"
    $Pool_CoinName   = $Pool_Coins.$Pool_Algorithm.Name
    $Pool_CoinSymbol = $Pool_Coins.$Pool_Algorithm.Symbol
    $Pool_PoolFee    = [Double]$Pool_Request.$_.fees

    $PoolCoins_Result = $PoolCoins_Request.PSObject.Properties.Value | Where-Object {$_.algo -eq $Pool_Algorithm -and [double]$_.estimate -gt 0}

    if (-not $PoolCoins_Result -and -not $InfoOnly) {return}

    if ($Pool_CoinName -and -not $Pool_CoinSymbol) {$Pool_CoinSymbol = Get-CoinSymbol $Pool_CoinName}

    if ($Pool_Algorithm -in @("ethash","kawpow") -and $Pool_CoinSymbol) {
        $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm -CoinSymbol $Pool_CoinSymbol
    } else {
        if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
        $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    }

    if (-not $InfoOnly -and (($Algorithm -and $Pool_Algorithm_Norm -notin $Algorithm) -or ($ExcludeAlgorithm -and $Pool_Algorithm_Norm -in $ExcludeAlgorithm))) {return}
    if (-not $InfoOnly -and $Pool_CoinSymbol -and (($CoinSymbol -and $Pool_CoinSymbol -notin $CoinSymbol) -or ($ExcludeCoinSymbol -and $Pool_CoinSymbol -in $ExcludeCoinSymbol))) {return}

    $Pool_EthProxy = $Pool_CoinSymbolMax = $null
    if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {
        $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethstratum2"} else {"stratum"}
        if (-not $Pool_CoinSymbol) {
            $Algo_Coins = $PoolCoins_Request.PSObject.Properties | Where-Object {$_.Value.algo -eq $Pool_Algorithm} | Foreach-Object {$_.Name}
            if ($Algo_Coins) {
                $Pool_CoinSymbolMax = Get-EthDAGSizeMax -CoinSymbols $Algo_Coins -Algorithm $Pool_Algorithm_Norm
                if ($Pool_CoinSymbolMax.CoinSymbol -and $Pool_Algorithm -in @("ethash","kawpow")) {
                    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm -CoinSymbol $Pool_CoinSymbolMax.CoinSymbol
                }
            }
        }
    }

    $Pool_Factor = [double]$Pool_Request.$_.mbtc_mh_factor
    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    $Pool_TSL = ($PoolCoins_Result | Measure-Object timesincelast -Minimum).Minimum
    $Pool_BLK = ($PoolCoins_Result | Measure-Object "24h_blocks" -Maximum).Maximum
    
    if (-not $InfoOnly) {
        $NewStat = $false
        $Pool_DataWindow = if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")) {$NewStat = $true;"actual_last24h"} else {$DataWindow}
        $Pool_Price = Get-YiiMPValue $Pool_Request.$_ -DataWindow $Pool_DataWindow -Factor $Pool_Factor
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $(-not $NewStat) -Actual24h $($Pool_Request.$_.actual_last24h/1000) -Estimate24h $($Pool_Request.$_.estimate_last24h) -HashRate $Pool_Request.$_.hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if ($Pool_Algorithm_Norm -eq "FiroPow" -and $Pool_CoinSymbol -eq "SCC") {
        $Pool_CoinSymbol = $Pool_CoinName = $null
    }

    foreach($Pool_SSL in ($false,$true)) {
        if ($Pool_SSL) {
            if (-not $Pool_Request.$_.ssl_port) {continue}
            $Pool_Port_SSL = [int]$Pool_Request.$_.ssl_port
            $Pool_Protocol = "stratum+ssl"
        } else {
            $Pool_Port_SSL = [int]$Pool_Request.$_.port
            $Pool_Protocol = "stratum+tcp"
        }
        foreach($Pool_Region in $Pool_Regions) {
            foreach($Pool_Currency in $Pool_Currencies) {
                $Pool_Params = if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"}
                [PSCustomObject]@{
                    Algorithm          = $Pool_Algorithm_Norm
                    Algorithm0         = $Pool_Algorithm_Norm
                    CoinName           = $Pool_CoinName
                    CoinSymbol         = $Pool_CoinSymbol
                    Currency           = $Pool_Currency
                    Price              = $Stat.$StatAverage #instead of .Live
                    StablePrice        = $Stat.$StatAverageStable
                    MarginOfError      = $Stat.Week_Fluctuation
                    Protocol           = $Pool_Protocol
                    Host               = "$Pool_Algorithm.$Pool_Region.$Pool_Host"
                    Port               = $Pool_Port_SSL
                    User               = $Wallets.$Pool_Currency
                    Pass               = "{workername:$Worker},c=$Pool_Currency{diff:,sd=`$difficulty}$Pool_Params"
                    Region             = $Pool_RegionsTable.$Pool_Region
                    SSL                = $Pool_SSL
                    SSLSelfSigned      = $Pool_SSL
                    Updated            = $Stat.Updated
                    PoolFee            = $Pool_PoolFee
                    DataWindow         = $DataWindow
                    Hashrate           = $Stat.HashRate_Live
                    Workers            = $Pool_Request.$_.workers
                    BLK                = $Stat.BlockRate_Average
                    TSL                = $Pool_TSL
                    EthMode            = $Pool_EthProxy
                    CoinSymbolMax      = $Pool_CoinSymbolMax.CoinSymbol
                    DagSizeMax         = $Pool_CoinSymbolMax.DagSize
                    ErrorRatio         = $Stat.ErrorRatio
                    Name               = $Name
                    Penalty            = 0
                    PenaltyFactor      = 1
                    Disabled           = $false
                    HasMinerExclusions = $false
                    Price_0            = 0.0
                    Price_Bias         = 0.0
                    Price_Unbias       = 0.0
                    Wallet             = $Wallets.$Pool_Currency
                    Worker             = "{workername:$Worker}"
                    Email              = $Email
                }
            }
        }
    }
}
