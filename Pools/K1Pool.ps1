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
    [String]$StatAverageStable = "Week"
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Request = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://api.rbminer.net/data/k1pool.json" -tag $Name -timeout 30 -cycletime 3600 
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed."
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","us","cn")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Request | Where-Object {$_.name -notmatch "solo$" -and ($Wallets."$($_.symbol)" -or $InfoOnly)} | ForEach-Object {
    $Pool_Currency       = $_.symbol    
    $Pool_Coin           = Get-Coin $Pool_Currency
    
    if ($Pool_Coin) {
        $Pool_Algorithm_Norm = $Pool_Coin.Algo
        $Pool_CoinName       = $Pool_Coin.Name
    } else {
        $Pool_Algorithm_Norm = Get-Algorithm $_.algo
        $Pool_CoinName       = (Get-Culture).TextInfo.ToTitleCase($_.name)
    }

    $Pool_Fee            = $_.fee
    $Pool_User           = $Wallets.$Pool_Currency
    $Pool_EthProxy       = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethstratum1"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pools_StatsRequest = [PSCustomObject]@{}
    try {
        $Pools_StatsRequest = Invoke-RestMethodAsync "https://k1pool.com/api/blocks/$($_.name)" -tag $Name -timeout 30 -cycletime 120 
    }
    catch {
        Write-Log -Level Warn "Pool API ($Name) for pool $($_.name) has failed."
        return
    }

    if (-not $InfoOnly) {

        if ($Pools_StatsRequest.pool.coinBlocktime) {
            $Pool_BLK        = 86400 / $Pools_StatsRequest.pool.coinBlocktime * $Pools_StatsRequest.pool.poolHashrate / $Pools_StatsRequest.pool.networkSpeed * $Pools_StatsRequest.pool.poolLuck / 100
        } else {
            $timestamp       = Get-UnixTimestamp
            $timestamp24h    = $timestamp - 86400

            $blocks          = @($Pools_StatsRequest.blocks.candidates | Select-Object -ExpandProperty timestamp | Where-Object {$_ -ge $timestamp24h}) + @($Pools_StatsRequest.blocks.immature | Select-Object -ExpandProperty timestamp | Where-Object {$_ -ge $timestamp24h}) + @($Pools_StatsRequest.blocks.matured | Select-Object -ExpandProperty timestamp | Where-Object {$_ -ge $timestamp24h})
            $blocks_measure  = $blocks | Measure-Object -Minimum -Maximum
            $Pool_BLK        = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
        }
        $Pool_TSL        = [int]($timestamp - [decimal]$Pools_StatsRequest.blocks.lastBlockFound)
                    
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate ([int64]$Pools_StatsRequest.pool.poolHashrate) -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach ($Pool_Region in $_.stratum.PSObject.Properties.Name) {
        foreach ($Pool_Host_Data in $_.stratum.$Pool_Region) {
            [PSCustomObject]@{
                Algorithm     = "$(if ($Pool_Currency -eq "ZIL") {"ZilliqaDual"} else {$Pool_Algorithm_Norm})"
                Algorithm0    = "$(if ($Pool_Currency -eq "ZIL") {"ZilliqaDual"} else {$Pool_Algorithm_Norm})"
                CoinName      = $Pool_CoinName
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = if ($Pool_Currency -eq "ZIL") {3e-16} else {0}
                StablePrice   = if ($Pool_Currency -eq "ZIL") {3e-16} else {0}
                MarginOfError = 0
                Protocol      = "stratum+$(if ($Pool_Host_Data.ssl) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_Host_Data.host)"
                Port          = $Pool_Host_Data.port
                User          = "$($Pool_User).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = [bool]$Pool_Host_Data.ssl
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $Pool_Fee
                Workers       = [int]$Pools_StatsRequest.pool.minersTotal
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                WTM           = $Pool_Currency -ne "ZIL"
                EthMode       = $Pool_EthProxy
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Pool_User
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
