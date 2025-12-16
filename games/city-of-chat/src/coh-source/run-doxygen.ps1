$currentDirectory = Get-Location
$doxyfiles = Get-ChildItem -Path $currentDirectory.Path -Filter Doxyfile -Recurse -ErrorAction SilentlyContinue -Force

$doxyfiles | %{
    Write-Host Processing $_.Directory.Name
    cd $_.Directory.FullName
    doxygen $_.FullName
    cd $currentDirectory.Path
}