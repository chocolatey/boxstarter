========================================
PowershellUtils package for Sublime Text
========================================

This plugin provides an interface to filter buffer text through a Windows
Powershell pipeline and run and capture Powershell commands.

Requirements
============

**Windows Powershell v2**

Windows Powershell v2 is preinstalled in Windows 7 and later and it's available
for previous versions of Windows too under the name `Windows Management Framework`.

Powershell is a powerful languange and needs to be used carefully to avoid
undesired effects.

Getting Started
===============

* Install `PowershellUtils`_
* Install `AAAPackageDev`_ (dependency)

.. _PowershellUtils: https://bitbucket.org/guillermooo/powershellutils/downloads/PowershellUtils.sublime-package
.. _AAAPackageDev: https://bitbucket.org/guillermooo/aaapackagedev/downloads/AAAPackageDev.sublime-package

If you're running a full installation, simply double click on the ``.sublime-package`` files.
If you're running a portable installation, perform an `installation by hand`_.

.. _installation by hand: http://sublimetext.info/docs/extensibility/packages.html#installation-of-packages-with-sublime-package-archives

Lastly, run ``run_powershell`` from the Python console or bind this command to
a key combination::

   # In Sublime's Python console.
   view.run_command("sublime_cmd")


Using The Windows Powershell Pipeline
=====================================

1. Execute ``run_powershell``
2. Type in your Windows Powershell command
3. Press ``enter``

All the currently selected regions in Sublime Text will be piped into your
command sequencially. In turn, you can access each of this regions through the
``$_`` automatic variable.

Roughly, this is what goes on behind the scenes::

    reg1..regN | <your command> | out-string

You can ignore the piped content and treat your command as the start point of
the pipeline.

The generated output will be inserted into each region in turn.

Using Intrinsic Commands
------------------------

(Not all intrinsic commands work.)

The following commands have a special meaning for this plugin:

    ``!mkh``
        Saves the session's history of commands to a file.
    ``!h``
        Brings up the history of commands so you can choose one and run it again.

Examples
--------

``$_.toupper()``
    Turns each region's content to all caps.
``$_ -replace "\\","/"``
    Replaces each region's content as indicated.
``"$(date)"``
    Replaces each region's content with the current date.
``"$pwd"``
    Replaces each region's content with the current working directory.
``[environment]::GetFolderPath([environment+specialfolder]::MyDocuments)``
    Replaces each region's content with the path to the user's ``My Documents`` folder.
``0..6|%{ "$($_+1) $([dayofweek]$_)" }``
    Replaces each region's content with the enumerated week days.

Caveats
-------

To start a Windows Powershell shell, do either ``Start-Process powershell`` or
``cmd /k start powershell``, but don't call Windows Powershell directly because
it will be launched in windowless mode and will block Sublime Text forever.
Should this happen to you, you can execute the following command from an actual
Windows Powershell prompt to terminate all Windows Powershell processes except
for the current session::

    Get-Process powershell | Where-Object { $_.Id -ne $PID } | Stop-Process

Alternatively, you can use a shorter version::

    gps powershell|?{$_.id -ne $pid}|kill


Other Ways of Using PowershellUtils
===================================

PowershellUtils can be called with arguments so that the *prompt* is bypassed.
This is interesting if you want to integrate powershell with a separate plugin.