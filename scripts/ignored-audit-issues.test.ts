// Tests for reading the audit's ignored issues from a result bundle's
// attachments (scripts/lib/ignored-audit-issues.ts). Run with:
// node --test scripts/ignored-audit-issues.test.ts

import assert from "node:assert/strict";
import { test } from "node:test";

import { ignoredAuditIssueNames } from "./lib/ignored-audit-issues.ts";

test("counts each ignored issue across tests and leaves the other attachments out", () => {
    const manifest = [
        {
            attachments: [
                { suggestedHumanReadableName: "Ignored audit issue: dynamicType locationNameField_0_2C3E1638-691C-45C2-811F-F5F56236A73C.txt" },
                { suggestedHumanReadableName: "Complete Issue Description.txt" },
                { suggestedHumanReadableName: "-[CardFormAccessibilityAuditTests testLocationPicker] audit_0_40DD981E-89B8-4A19-8911-94ED9EFD1F4B.png" },
            ],
        },
        {
            attachments: [
                // xcresulttool drops the colon from a name it exports.
                { suggestedHumanReadableName: "Ignored audit issue dynamicType locationNameField_1_906DD38B-386A-4669-98ED-5F3DA7257780.txt" },
                { suggestedHumanReadableName: "Ignored audit issue: contrast distanceUnitsFooter" },
            ],
        },
    ];
    assert.deepEqual(ignoredAuditIssueNames(manifest), ["contrast distanceUnitsFooter", "dynamicType locationNameField ×2"]);
});

test("is empty when nothing was ignored", () => {
    assert.deepEqual(ignoredAuditIssueNames([{ attachments: [{ suggestedHumanReadableName: "App Screenshot_0_848B8387-344F-4776-81E6-B0C0ED5ED3B6.png" }] }]), []);
});
