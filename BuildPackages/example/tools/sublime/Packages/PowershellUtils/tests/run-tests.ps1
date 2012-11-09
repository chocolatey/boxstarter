$__old_PYTHONPATH = $env:PYTHONPATH
$env:PYTHONPATH = (resolve-path "..").providerpath

# run tests here
get-item "test_*.py" | foreach-object { & $_ }

$env:PYTHONPATH = $__old_PYTHONPATH
