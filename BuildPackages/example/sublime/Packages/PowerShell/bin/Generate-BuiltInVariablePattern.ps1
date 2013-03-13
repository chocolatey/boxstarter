$command = {

    [string] $result

    get-variable | select-object -property name | `
        foreach-object { $result += "|$($_.name)" }

    # TODO: Isn't there a neater way of doing this?
    $OFS = ""
    $result = "$($result[1..$result.length])"

    # Escape where needed

    "(\\$)(?i:(($($result -replace "(\`$|\?|\^)","\\`$1")))"
}

# Make sure we only get builtin variables.
$result = powershell.exe -noprofile -command $command

# This will fail on Win Vista and lower.
trap { write-warning "Couldn't find clip.exe. Result not copied to clipboard."; continue }
$result | clip.exe
$result