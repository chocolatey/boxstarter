^+C::
IfWinExist Console
{
    WinActivate
}
else
{
    Run Console
    WinWait Console
    WinActivate
}