#!/usr/bin/env lua5.2

-- Simple test script to verify text rendering modes work
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/words-pdf"

package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/libharu-RELEASE_2_3_0/build/src/?.so"

hpdf = require "hpdf"

local function test_text_effects()
    local pdf = hpdf.New()
    local page = hpdf.AddPage(pdf)
    hpdf.Page_SetSize(page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
    
    local font = hpdf.GetFont(pdf, "Helvetica-Bold", "StandardEncoding")
    
    -- Test STROKE mode specifically
    hpdf.Page_SetFontAndSize(page, font, 36)
    hpdf.Page_SetRGBFill(page, 1.0, 1.0, 1.0)  -- White fill
    hpdf.Page_SetRGBStroke(page, 1.0, 0.0, 0.0) -- Red stroke
    hpdf.Page_SetLineWidth(page, 3.0)
    hpdf.Page_SetTextRenderingMode(page, "HPDF_STROKE")
    
    hpdf.Page_BeginText(page)
    hpdf.Page_TextOut(page, 100, 700, "STROKE TEST")
    hpdf.Page_EndText(page)
    
    -- Test FILL_THEN_STROKE mode
    hpdf.Page_SetRGBFill(page, 0.0, 0.0, 1.0)  -- Blue fill
    hpdf.Page_SetRGBStroke(page, 1.0, 0.0, 0.0) -- Red stroke
    hpdf.Page_SetLineWidth(page, 2.0)
    hpdf.Page_SetTextRenderingMode(page, "HPDF_FILL_THEN_STROKE")
    
    hpdf.Page_BeginText(page)
    hpdf.Page_TextOut(page, 100, 600, "FILL+STROKE TEST")
    hpdf.Page_EndText(page)
    
    -- Save
    hpdf.SaveToFile(pdf, DIR .. "/test-text-effects-output.pdf")
    hpdf.Free(pdf)
    
    print("Simple text effects test saved to test-text-effects-output.pdf")
end

test_text_effects()