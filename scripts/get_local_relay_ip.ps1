$route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
    Sort-Object RouteMetric |
    Select-Object -First 1

if ($null -eq $route) {
    exit 0
}

$address = Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' } |
    Select-Object -First 1 -ExpandProperty IPAddress

if ($null -ne $address) {
    Write-Output $address
}