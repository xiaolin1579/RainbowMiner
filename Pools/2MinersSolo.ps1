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

$Pool_Region_Default = "eu"

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_HostStatus = [PSCustomObject]@{}

try {
    $Pool_HostStatus = Invoke-RestMethodAsync "https://status-api.2miners.com/" -tag $Name -retry 5 -retrywait 200 -cycletime 120
    if ($Pool_HostStatus.code -ne $null) {throw}
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

# Create basic structure
#$Pool_Home = Invoke-WebRequest "https://2miners.com" -UseBasicParsing -TimeoutSec 10
#$Pool_Home.Links | Where {$_.class -eq "link pools-list__item" -and $_.href -notmatch "solo-" -and $_.outerHTML -match "/(.+?)-mining-pool.+?>(.+?)<"} | Foreach-Object {
#    $Short = $Matches[1]
#    $Name  = $Matches[2]
#    $Pool_Request | where {$_.host -match "^$($Short).2miners.com"} | select-object -first 1 | foreach {"[PSCustomObject]@{host = `"$($_.host)`"; coin = `"$($Name)`"; algo = `"`"; symbol = `"$(($_.host -split '\.' | Select -First 1).ToUpper())`";    port = $($_.port); fee = 1}"}
#}
# List of coins
#$Pool_HostStatus | where-object {$_.host -notmatch "^solo" -and $_.host -match "^([a-z]+)\."} | Foreach-Object {$Matches[1]} | select-object -unique | sort-object

$Pools_Data = @(
    [PSCustomObject]@{rpc = "ae";    symbol = "AE";       port = 4141; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "beam";  symbol = "BEAM";     port = 5454; fee = 1.0; divisor = 1e8; ssl = $true}
    [PSCustomObject]@{rpc = "btg";   symbol = "BTG";      port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "ckb";   symbol = "CKB";      port = 6767; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "clore"; symbol = "CLORE";    port = 3030; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "ctxc";  symbol = "CTXC";     port = 6666; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "erg";   symbol = "ERG";      port = 9999; fee = 1.0; divisor = 1e9}
    [PSCustomObject]@{rpc = "etc";   symbol = "ETC";      port = 5050; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "ethw";  symbol = "ETHW";     port = 6060; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "firo";  symbol = "FIRO";     port = 9090; fee = 1.0; divisor = 1e8; altsymbol = "XZC"}
    [PSCustomObject]@{rpc = "flux";  symbol = "FLUX";     port = 9393; fee = 1.0; divisor = 1e8; altsymbol = "ZEL"}
    [PSCustomObject]@{rpc = "grin";  symbol = "GRIN-PRI"; port = 4040; fee = 1.0; divisor = 1e9; cycles = 42}
    [PSCustomObject]@{rpc = "kas";   symbol = "KAS";      port = 3030; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "kls";   symbol = "KLS";      port = 3030; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "neox";  symbol = "NEOX";     port = 5050; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "nexa";  symbol = "NEXA";     port = 7070; fee = 1.0; divisor = 100}
    [PSCustomObject]@{rpc = "pyi";   symbol = "PYI";      port = 3131; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "rvn";   symbol = "RVN";      port = 7070; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "xmr";   symbol = "XMR";      port = 4444; fee = 1.0; divisor = 1e12}
    [PSCustomObject]@{rpc = "xna";   symbol = "XNA";      port = 7070; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zec";   symbol = "ZEC";      port = 1010; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zeph";  symbol = "ZEPH";     port = 4444; fee = 1.0; divisor = 1e12}
    [PSCustomObject]@{rpc = "zen";   symbol = "ZEN";      port = 7070; fee = 1.0; divisor = 1e8}
)

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol -replace "-.+$";$Wallets.$Pool_Currency -or ($_.altsymbol -and $Wallets."$($_.altsymbol)") -or $InfoOnly} | ForEach-Object {
    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Port = $_.port
    $Pool_Algorithm_Norm = $Pool_Coin.Algo
    $Pool_Host = "solo-$($_.rpc).2miners.com"
    $Pool_Fee = $_.fee
    $Pool_Divisor = $_.divisor
    $Pool_FixBigInt = $Pool_Divisor -ge 1e18
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}
    $Pool_SSL = $_.ssl

    if (-not ($Pool_Wallet = $Wallets.$Pool_Currency)) {
        $Pool_Wallet = $Wallets."$($_.altsymbol)"
    }

    $ok = ($Pool_HostStatus | Where-Object {$_.host -match "$($Pool_Host)"} | Measure-Object).Count -gt 0
    if ($ok -and -not $InfoOnly) {
        $Pool_Blocks = [PSCustomObject]@{}

        try {
            $Pool_Blocks = Invoke-RestMethodAsync "https://$($_.rpc).2miners.com/api/blocks" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250 -fixbigint:$Pool_FixBigInt
            if ($Pool_Blocks.code -ne $null) {$ok=$false}
        }
        catch {
            $ok = $false
        }

        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            return
        }

        $Pool_Request = [PSCustomObject]@{}
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_Host)/api/stats" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250
            if ($Pool_Request.code -ne $null -or $Pool_Request.nodes -eq $null -or -not $Pool_Request.nodes) {$ok=$false}
        }
        catch {
            $ok = $false
        }

        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            return
        }

        $timestamp    = [int]($Pool_Request.now / 1000)
        $timestamp24h = $timestamp - 24*3600
            
        $blocks = @($Pool_Blocks.candidates | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) + @($Pool_Blocks.immature | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) + @($Pool_Blocks.matured | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) | Select-Object

        $blocks_measure = $blocks | Measure-Object timestamp -Minimum -Maximum
        $avgTime        = if ($blocks_measure.Count -gt 1) {($blocks_measure.Maximum - $blocks_measure.Minimum) / ($blocks_measure.Count - 1)} else {$timestamp}
        $reward         = $(if ($blocks) {($blocks | Where-Object {$_.reward -gt 0} | Measure-Object reward -Average).Average} else {0})/$Pool_Divisor
        $btcPrice       = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}

        $node           = $Pool_Request.nodes | Select-Object -First 1
        $difficulty     = [double]$node.networkhashps * $node.avgBlockTime / 4294967296 #2^32

        if ($_.cycles) {
            $addName         = $Pool_Algorithm_Norm -replace "[^\d]"
            $PBR  = (86400 / $_.cycles) * ($(if ($_.symbol -match "-PRI$") {$Pool_Request.nodes."primaryWeight$($addName)"} else {$Pool_Request.nodes.secondaryScale})/[double]$node.difficulty)
            $btcRewardLive   = $PBR * $reward * $btcPrice
            $Divisor         = 1
        } else {
            $btcRewardLive   = if ($Pool_Request.hashrate -gt 0) {$btcPrice * $reward * 86400 / $avgTime / $Pool_Request.hashrate} else {0}
            $addName         = ""
            $Divisor         = 1
        }
        $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value ($btcRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $false -Difficulty $difficulty -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if ($ok) {
        [System.Collections.Generic.List[string]]$Pool_Hosts = @()
        $Pool_Wallet = Get-WalletWithPaymentId $Pool_Wallet -pidchar '.'
        $Pool_HostStatus_Select = $Pool_HostStatus | Where-Object {$_.host -match "$($Pool_Host)"} | Select-Object host,port | Sort-Object -Descending:$($Pool_Currency -eq "FIRO") {[int]$_.port}
        $Pool_HostStatus_Select | Foreach-Object {
            $Pool_Host_0   = "$($_.host)"
            $Pool_Port     = [int]$_.port
            $Pool_SSL_0    = $Pool_SSL -or ($Pool_Port -ge 10000)
            $Pool_Protocol = if ($Pool_SSL_0) {"stratum+ssl"} else {"stratum+tcp"}
            if ($Pool_Hosts -notcontains "$($_.host)$($Pool_SSL_0)") {
                [void]$Pool_Hosts.Add("$($_.host)$($Pool_SSL_0)")
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin.Name
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = $Pool_Protocol
                    Host          = $Pool_Host_0
                       port          = $Pool_Port
                    User          = "$($Pool_Wallet).{workername:$Worker}"
                    Pass          = "x"
                    Region        = $Pool_RegionsTable."$(if ($_.host -match "^(asia|us)-") {$Matches[1]} else {"eu"})"
                    SSL           = $Pool_SSL_0
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                    DataWindow    = $DataWindow
                    Workers       = $null
                    Hashrate      = $null
                    TSL           = $null
                    BLK           = $null
                    Difficulty    = $Stat.Diff_Average
                    SoloMining    = $true
                    EthMode       = $Pool_EthProxy
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Disabled      = $false
                    HasMinerExclusions = $false
                    Price_0       = 0.0
                    Price_Bias    = 0.0
                    Price_Unbias  = 0.0
                    Wallet        = $Pool_Wallet
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
        }
    }
}
