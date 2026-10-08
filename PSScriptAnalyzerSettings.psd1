@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # The scripts are interactive console tools: Write-Host output is intentional.
        'PSAvoidUsingWriteHost'
        # Style-only rules that do not fit these small, self-contained scripts.
        # Functions act on several items on purpose, and state changes are
        # guarded by the script-level SupportsShouldProcess where it matters.
        'PSUseSingularNouns'
        'PSUseShouldProcessForStateChangingFunctions'
        'PSShouldProcess'
    )
}
