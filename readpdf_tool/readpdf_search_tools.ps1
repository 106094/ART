    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    if ($PSScriptRoot) {
    $rootpath = $PSScriptRoot
} else {
    $rootpath = [System.AppDomain]::CurrentDomain.BaseDirectory
}
    $zipname=(Get-ChildItem $rootpath |Where-Object{$_.name -eq "modules.zip"}).FullName
    #$zipname
    $unzippath="$rootpath\modules"
    #$unzippath
    if (!(Test-Path $unzippath) ){        
     Expand-Archive $zipname -DestinationPath $unzippath -Force
    }
    $assemblies=Get-ChildItem -path $unzippath -r |Where-Object{$_.name -match ".dll"}
    foreach($assembly in $assemblies){
        Unblock-File $assembly.fullname 
    try{
        add-type -Path $assembly.fullname
        #Write-Host "PASS:"
        #$assembly.fullname 

    }
    catch{
        #Write-Host "FAIL:"
        #$assembly.fullname
    }
    }
$mainpath=(read-host "Input the pdf path").trim()
$OutputHtml=Join-Path -Path $mainpath -ChildPath "pdfcontent_search.html"
$pdfs=Get-ChildItem -path $mainpath -r -filter *.pdf

# Build the final HTML with search functionality
$htmlHeader = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>PDF Search - OR / AND Mode Switch</title>
<style>
    body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
    h1 { text-align: center; color: #333; }
    #controls { max-width: 800px; margin: 20px auto; text-align: center; }
    #searchContainer { position: relative; display: inline-block; width: 100%; }
    #searchBox {
        width: 100%; padding: 15px 15px 50px 15px; font-size: 20px;
        border: 2px solid #007cba; border-radius: 8px; box-sizing: border-box;
    }
    #liveTag {
        position: absolute; bottom: 10px; left: 12px; z-index: 10;
        display: none; background: #007cba; color: white; padding: 8px 16px;
        border-radius: 30px; font-weight: bold; font-size: 15px;
    }
    #liveTag .clear { margin-left: 10px; cursor: pointer; font-size: 20px; }
    #modeSwitch {
        margin-top: 15px; font-size: 18px;
    }
    #modeSwitch label { margin: 0 15px; cursor: pointer; font-weight: bold; }
    #modeSwitch input:checked + span { color: #007cba; text-decoration: underline; }
    #keywordList { text-align: center; margin: 25px 0; }
    .kw {
        display: inline-block; margin: 6px; padding: 10px 20px;
        background: #e0e0e0; color: #333; border-radius: 30px;
        cursor: pointer; user-select: none; transition: 0.2s;
    }
    .kw.selected, #liveTag { background: #007cba; color: white; font-weight: bold; }
    .page-block { margin: 30px 0; padding: 20px; background: white; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
    .page-header { font-weight: bold; color: Tomato; font-size: 1.4em; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 2px solid #ff6347; }
    .line { margin: 8px 0; line-height: 1.6; }
    .line.hidden { display: none; }
    mark { background: #ffeb3b; padding: 0 3px; border-radius: 3px; font-weight: bold; }
    #noResult { text-align: center; color: red; font-size: 2em; margin: 80px; }
</style>
</head>
<body>
<h1>PDF(s) Content Search</h1>

<div id="controls">
    <div id="searchContainer">
        <input type="text" id="searchBox" placeholder="Type anything to search" autofocus>
        <div id="liveTag"><span id="liveTagText"></span> <span class="clear">&times;</span></div>
    </div>

    <div id="modeSwitch">
        Search mode:
        <label><input type="radio" name="mode" value="or" checked> <span>OR</span></label>
        <label><input type="radio" name="mode" value="and"> <span>AND</span></label>
    </div>
</div>

<div id="keywordList">
keywordListhtml
</div>

<div id="content">
'@

$htmlFooter = @'
</div>

<script>
document.addEventListener('DOMContentLoaded', () => {
    const searchBox   = document.getElementById('searchBox');
    const liveTag     = document.getElementById('liveTag');
    const liveTagText = document.getElementById('liveTagText');
    const clearBtn    = document.querySelector('#liveTag .clear');
    const keywords    = document.querySelectorAll('.kw');
    const blocks      = document.querySelectorAll('.page-block');
    const modeRadios  = document.querySelectorAll('input[name="mode"]');
    let selectedKeywords = new Set();

    // Tag clicking
    keywords.forEach(kw => {
        kw.addEventListener('click', () => {
            const word = kw.dataset.kw.toLowerCase();
            if (selectedKeywords.has(word)) {
                selectedKeywords.delete(word);
                kw.classList.remove('selected');
            } else {
                selectedKeywords.add(word);
                kw.classList.add('selected');
            }
            filterContent();
        });
    });

    // Clear live tag
    clearBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        searchBox.value = '';
        liveTag.style.display = 'none';
        filterContent();
    });

    // Search box
    searchBox.addEventListener('input', () => {
        const term = searchBox.value.trim();
        liveTag.style.display = term ? 'inline-block' : 'none';
        if (term) liveTagText.textContent = term;
        filterContent();
    });

    // Mode change
    modeRadios.forEach(r => r.addEventListener('change', filterContent));

    function filterContent() {
        const manualTerm = searchBox.value.trim().toLowerCase();
        const activeTerms = [...selectedKeywords];
        if (manualTerm) activeTerms.push(manualTerm);

        const isAndMode = document.querySelector('input[name="mode"]:checked').value === 'and';

        document.getElementById('noResult')?.remove();

        if (activeTerms.length === 0) {
            document.querySelectorAll('.page-block, .line').forEach(el => {
                el.style.display = ''; el.classList.remove('hidden');
            });
            document.querySelectorAll('mark').forEach(m => m.outerHTML = m.textContent);
            return;
        }

        let anyMatch = false;

        blocks.forEach(block => {
            const lines = block.querySelectorAll('.line');
            let blockHasMatch = false;

            lines.forEach(line => {
                const text = line.textContent.toLowerCase();

                const matches = isAndMode
                    ? activeTerms.every(t => text.includes(t))   // AND
                    : activeTerms.some(t => text.includes(t));   // OR

                if (matches) {
                    blockHasMatch = true;
                    anyMatch = true;

                    let html = line.textContent;
                    activeTerms.forEach(t => {
                        const regex = new RegExp(t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
                        html = html.replace(regex, m => `<mark>${m}</mark>`);
                    });
                    line.innerHTML = html;
                    line.classList.remove('hidden');
                } else {
                    line.innerHTML = line.textContent;
                    line.classList.add('hidden');
                }
            });

            block.style.display = blockHasMatch ? '' : 'none';
        });

        if (!anyMatch) {
            document.getElementById('content').insertAdjacentHTML('beforeend',
                `<p id="noResult">No lines match (${isAndMode ? 'ALL' : 'ANY'}) of the selected keywords.</p>`);
        }
    }

    filterContent();
});
</script>
</body>
</html>
'@

#keywords list embed from external txt
$addkeywords=Get-Content -Path "$rootpath\keywords.txt"
$keywordListhtml= ($addkeywords | ForEach-Object { "<span class='kw' data-kw='$($_.Trim())'> $($_.Trim()) </span>" }) -join "`n"
$htmlHeader = $htmlHeader -replace "keywordListhtml", $keywordListhtml

# === Build content (same as before) ===
$htmlParts = @()
$htmlParts += $htmlHeader

foreach ($pdf in $pdfs) {
    $pdfPath = $pdf.FullName
    $fileName = $pdf.Name
    $filepath ="<font style='color:#6a5acd'>"+$($pdfPath.Replace($mainpath,"").Replace($fileName,"")).TrimStart("\")+"</font>"
    $filepathName=$filepath+$fileName
    try {
        $bytes = [System.IO.File]::ReadAllBytes($pdfPath)
        $reader = New-Object iTextSharp.text.pdf.PdfReader -ArgumentList (,[byte[]]$bytes)

        for ($page = 1; $page -le $reader.NumberOfPages; $page++) {
            $strategy = New-Object iTextSharp.text.pdf.parser.LocationTextExtractionStrategy
            $currentText = [iTextSharp.text.pdf.parser.PdfTextExtractor]::GetTextFromPage($reader, $page, $strategy)
            $lines = $currentText -split "`r?`n" | Where-Object { $_.Trim() }

            if ($lines.Count -gt 0) {
                $htmlParts += "<div class='page-block'>"
                $htmlParts += "<div class='page-header'>$($($filepathName)+" - Page "+$($page))</div>"
                foreach ($line in $lines) {
                    $htmlParts += "<div class='line'>$([System.Web.HttpUtility]::HtmlEncode($line))</div>"
                }
                $htmlParts += "</div>"
            }
        }
        $reader.Close()
    }
    catch {
        $htmlParts += "<div class='page-block' style='background:#ffebee;'><div class='page-header'>ERROR $($filepathName)</div><div class='line'>$([System.Web.HttpUtility]::HtmlEncode($_.Exception.Message))</div></div>"
    }
}

$htmlParts += $htmlFooter

# Save and open
$utf8WithBom = New-Object System.Text.UTF8Encoding $true   # $true = include BOM
[System.IO.File]::WriteAllText($OutputHtml, ($htmlParts -join "`r`n"), $utf8WithBom)
Invoke-Item $OutputHtml