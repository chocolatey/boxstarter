function Confirm-Choice {
<#
.SYNOPSIS
Prompts the user to choose a yes/no option.

.DESCRIPTION
The message parameter is presented to the user and the user is then prompted to
respond yes or no. In environments such as the PowerShell ISE, the Confirm param
is the title of the window presenting the message.

.Parameter Message
The message given to the user that tels them what they are responding yes/no to.

.Parameter Caption
The title of the dialog window that is presented in environments that present
the prompt in its own window. If not provided, the Message is used.

.LINK
https://boxstarter.org

#>
    param (
        [string]$Message,
        [string]$Caption = $Message
    )
    $yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Yes";
    $no = new-Object System.Management.Automation.Host.ChoiceDescription "&No","No";
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no);
    $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)

    switch ($answer){
        0 {return $true; break}
        1 {return $false; break}
    }
}
