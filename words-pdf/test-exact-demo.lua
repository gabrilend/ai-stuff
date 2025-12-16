#!/usr/bin/env lua5.2

-- Exact copy of working demo pattern
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/words-pdf"

package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/libharu-RELEASE_2_3_0/build/src/?.so"

hpdf = require "hpdf"

local function test_exact_demo()
    local pdf = hpdf.New()
    local page = hpdf.AddPage(pdf)
    hpdf.Page_SetSize(page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
    
    local font = hpdf.GetFont(pdf, "Helvetica-Bold", "StandardEncoding")
    hpdf.Page_SetFontAndSize(page, font, 30)
    
    local ypos = 700
    
    -- Set colors for stroke modes
    hpdf.Page_SetRGBFill(page, 0.0, 0.0, 1.0)   -- Blue fill
    hpdf.Page_SetRGBStroke(page, 1.0, 0.0, 0.0) -- Red stroke  
    hpdf.Page_SetLineWidth(page, 2.0)
    
    -- STROKE mode
    hpdf.Page_SetTextRenderingMode(page, "HPDF_STROKE")
    hpdf.Page_BeginText(page)
    hpdf.Page_TextOut(page, 60, ypos, "STROKE MODE")
    hpdf.Page_EndText(page)
    
    -- FILL_THEN_STROKE mode
    hpdf.Page_SetTextRenderingMode(page, "HPDF_FILL_THEN_STROKE")
    hpdf.Page_BeginText(page)
    hpdf.Page_TextOut(page, 60, ypos - 50, "FILL_THEN_STROKE")
    hpdf.Page_EndText(page)
    
    -- Save
    hpdf.SaveToFile(pdf, DIR .. "/test-exact-demo-output.pdf")
    hpdf.Free(pdf)
    
    print("Exact demo test saved to test-exact-demo-output.pdf")
end

test_exact_demo()