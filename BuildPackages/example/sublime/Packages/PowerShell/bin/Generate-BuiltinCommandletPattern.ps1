$command = {

    [string] $result

    get-command -commandtype cmdlet | select-object -property name | out-string
}

# Make sure we only get builtin variables.
$result = powershell.exe -noprofile -command $command

$subpatterns = @{}
$result -split "`n" | foreach-object {

    if ($_) {

        $_ = $_ -replace "\s",""
        $verb, $name = $_ -split "-"

        if ($subpatterns[$verb]){

            $subpatterns[$verb] += "|$name"
        }
        else {

            $subpatterns[$verb] = $name
        }
    }
}

[string] $a
$subpatterns.keys | sort-object | %{ $a += "$()" }

# This will fail on Win Vista and lower.
# trap { write-warning "Couldn't find clip.exe. Result not copied to clipboard."; continue }
# $result | clip.exe

# $result