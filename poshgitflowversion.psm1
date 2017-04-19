$m = "master"
$d = "develop"

function Set-Branch {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)]$name
    )
    process {
        Write-Host "git checkout $name" -ForegroundColor Green
        git checkout -q $name
    }
}

function Remove-Branch {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)]$name,
        [switch]$force
    )
    process {
        if ($force) {
            Write-Host "git branch -D $name" -ForegroundColor Green
            git branch -D $name
        }
        else {
            Write-Host "git branch -d $name" -ForegroundColor Green
            git branch -d $name
        }
    }
}

function Update-BranchFrom {
    <#
    .SYNOPSIS
    Updates the current branching using either a rebase or merge strategy
    .DESCRIPTION
    Updates the current branching using either a rebase or merge strategy
    .EXAMPLE
    Update-BranchFrom $d -rebase
    .EXAMPLE
    Update-BranchFrom $d -merge
    .EXAMPLE
    Update-BranchFrom $d -merge -noff
    .PARAMETER branch
    The source branch on where to rebase or merge from
    .PARAMETER rebase
    Sets the update strategy using git rebase
    .PARAMETER merge
    Sets the update strategy using git merge
    #>
    [cmdletbinding()]
    param(
        [Parameter(Position = 0)]$branch,
        [Parameter(ParameterSetName = "rebase", Position = 1)][switch]$rebase,
        [Parameter(ParameterSetName = "merge", Position = 1)][switch]$merge,
        [Parameter(ParameterSetName = "merge", Position = 2)][switch]$noff
    )
    process {
        if ($rebase) {
            Write-Host "git rebase $branch" -ForegroundColor Green
            git rebase $branch
        }
        else {
            if ($noff) {
                Write-Host "git merge --no-ff $branch" -ForegroundColor Green
                git merge --no-ff $branch
            }
            else {
                Write-Host "git merge $branch" -ForegroundColor Green
                git merge $branch
            }
        }
    }
}

function New-Tag  {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)]$tag
    )
    process {
        Write-Host "git tag -a v$tag -m version v$tag" -ForegroundColor Green
        git tag -a "v$tag" -m "version v$tag" --force
    }
}

function Resume-Rebase {
        git add -A
        git rebase --continue
}

function Start-Feature { 
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]$name
    )
    process {
        Write-Host "Starting new feature $name" -ForegroundColor Green
        $name = $name -replace "feature/", ""
        git checkout -q -b "feature/$name" $d
        return $name
    }
}

function Start-HotFix {
    process {
        Set-Branch $m
        $version = (gitversion | convertFrom-json)
        $major = [int]$version.Major
        $minor = [int]$version.Minor
        $patch = [int]$version.Patch + 1
        $name = "hotfix/$major`.$minor`.$patch"

        Write-Host "Starting new $name" -ForegroundColor Green
        git checkout -q -b $name $m

        return "hotfix/$major`.$minor`.$patch"
    }
}

function Complete-HotFix {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]$hotfixBranch
    )
    process { 
        Set-Branch $m
        Update-BranchFrom $hotfixBranch -merge -noff
        Remove-Branch $hotfixBranch
        $tag = ($hotfixBranch -split "/")[1]
        New-Tag $tag
    }
}

function Start-Release {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$false)][switch]$majorVersion
    )
    process { 
        Set-Branch $m
        $version = (gitversion | convertFrom-json)
        
        if($majorVersion) {
            $major = [int]$version.Major + 1
            $minor = [int]$version.Minor
        } else {
            $major = [int]$version.Major
            $minor = [int]$version.Minor + 1
        }
        $patch = [int]$version.Patch
        $name = "release/$major`.$minor`.$patch"

        Write-Host "Starting new $name" -ForegroundColor Green
        git checkout -q -b $name $d

        return $name;
    }
}

function Complete-Release {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]$releaseBranch
    ) 
    process { 
        Set-Branch $m

        $name = ($releaseBranch -split "/")[1]

        Update-BranchFrom $releaseBranch -merge -noff
        New-Tag $name

        Set-Branch $d
        Update-BranchFrom $m -rebase
        Remove-Branch $releaseBranch
    }
}

Export-ModuleMember -Variable *
Export-ModuleMember -Function Complete-HotFix,Complete-Release,New-Tag,Remove-Branch,Reset-Repo,Resume-Rebase,Set-Branch,Start-Feature,Start-HotFix,Start-Release,Test-Rebase,Update-BranchFrom
