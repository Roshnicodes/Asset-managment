# Text and screenshots of the in-app User Manual (English and Hindi).
# Each section is one task in the procurement flow, in the order it happens.
# Screenshots live in app/assets/images/manual/.
module UserManualContent
  module_function

  def for(language)
    language.to_s == "hi" ? hindi : english
  end

  def english
    {
      page_title: "Apurti User Manual",
      subtitle: "Simple step-by-step guide for vendor registration, Request for Proposal, approvals, vendor quotations, purchase orders, goods receive, invoices and payment.",
      updated_label: "Updated for the new flow",
      stakeholder_label: "Stakeholder",
      module_label: "Procurement workflow",
      download_label: "Download PDF",
      contents_label: "Contents",
      note_label: "Note",
      role_label: "Who",
      screenshot_label: "Screen",
      screenshot_note: "Click a screen to open it in full size.",
      quick_flow_title: "Full Flow",
      quick_flow: [
        "Login & Dashboard", "Vendor Registration", "Vendor Approval", "Request for Proposal",
        "RFP Approval", "Vendor Quotation", "Scoring & Selection", "Purchase Order",
        "Goods Receive", "Invoice", "Payment & Assets"
      ],
      role_guide_title: "Who should read what",
      role_guide: [
        { role: "Maker", body: "Adds vendors, creates Requests for Proposal, sends them, creates purchase orders, receives goods and reviews invoices.", sections: %w[vendor-registration vendor-link vendor-approval rfp vendor-rule rfp-approval purchase-order goods-invoice] },
        { role: "Approver", body: "Checks and approves, returns or rejects vendor registrations and requests.", sections: %w[vendor-approval rfp-approval] },
        { role: "Committee member", body: "Approves requests and gives marks to the vendors' quotations.", sections: %w[rfp-approval scoring] },
        { role: "Thematic Head", body: "Chooses the 1st committee member and With / Without Committee.", sections: %w[rfp-approval] },
        { role: "Vendor", body: "Registers through the SMS link, sends quotations, answers purchase orders and uploads invoices.", sections: %w[vendor-link vendor-response purchase-order goods-invoice] },
        { role: "Finance", body: "Records the payment of accepted invoices and sends the payment advice.", sections: %w[finance-assets] },
        { role: "Admin", body: "Sets users, menus, approval channels and Procurement Settings; can edit approved records.", sections: %w[admin] }
      ],
      statuses_title: "What the statuses mean",
      statuses: [
        ["Not sent / Not started", "Saved, but not yet sent for approval.", "slate"],
        ["Pending / In approval", "Waiting for an approver to act.", "amber"],
        ["Returned / Correction by maker", "Sent back to the maker to correct and save again.", "orange"],
        ["Approved", "All approvals are done.", "green"],
        ["Rejected", "Stopped by an approver; it will not continue.", "red"],
        ["Thematic Head decision", "Waiting for the Thematic Head to choose the 1st member and With / Without Committee.", "amber"],
        ["Committee approval", "The committee members are approving the request.", "amber"],
        ["Send to vendors", "Approved; the maker has to click Send To Vendor.", "blue"],
        ["Vendor quotation", "Waiting for the vendors to send their quotations.", "blue"],
        ["Max rate entry", "The maker has to enter the missing Max Rate of an item.", "orange"],
        ["Committee scoring", "Committee members have to give marks to the vendors.", "purple"],
        ["Vendor selected", "The vendor is chosen; the purchase order can be created.", "green"]
      ],
      faq_title: "Common problems and solutions",
      faqs: [
        ["Next does nothing.", "Something on this step is missing or wrong. Read the red message under the field, fix it and click Next again."],
        ["I cannot see a menu or a button.", "Menus and buttons follow your role. Ask the admin to check your designation, Menu Permissions and Approval Channel."],
        ["A vendor is not in the vendor list of my request.", "Only approved vendors of the selected theme are shown. Check that the vendor is approved and has that theme ticked."],
        ["I cannot select 2 vendors.", "Above 10K needs 3 or more vendors, or only 1 vendor with a Logic Note. Exactly 2 is not allowed."],
        ["My Logic Note is not accepted.", "It needs at least 50 words and no [ ] left from the format."],
        ["The 2nd or 3rd committee member is empty.", "The COO, Director and Programme Director - Finance must exist in Employee Master with exactly these designations."],
        ["The vendor did not get the OTP or it expired.", "Check the mobile number, then click Send New OTP on the vendor page."],
        ["I picked the wrong value in a dropdown.", "Click the dropdown again, type a few letters and choose the right one. Esc closes the list without a change."],
        ["The page shows old data or an old look.", "Press Ctrl + Shift + R to reload the page fully."]
      ],
      language_links: [{ code: "en", label: "English" }, { code: "hi", label: "हिंदी" }],
      intro_cards: [
        { title: "Start from the Dashboard", body: "After login, \"Needs your action\" shows every task waiting on you, and the Search box (Ctrl + K) finds any quotation, vendor or product." },
        { title: "Steps check themselves", body: "In every form, Next works only when the current step is complete. Red messages show what to fix." },
        { title: "Menus follow your role", body: "You see only the menus of your role. If a menu you need is missing, ask the admin." }
      ],
      sections: [
        {
          id: "getting-started", number: "01", role: "All users",
          title: "Login and Your Dashboard",
          steps: [
            "Open Apurti and login with your Employee Code and password. The Dashboard opens - the numbers below match the numbers on the screen.",
            "① Search: type a quotation subject, vendor name / firm / mobile / email or a product (at least 2 letters) and press Enter. Ctrl + K jumps to the search box. Next to it are the time, the date, your name and your role.",
            "② Summary cards - Vendor Registrations, Quotations, Purchase Orders, Approvals. The big number is the total (Approvals: pending with you); the coloured dots split it by status; the small graph shows the last months; the badge is the growth in the last 30 days (\"New\" = first records in the last 30 days). Click a card to open its list.",
            "③ Needs your action: every task waiting on you with a count (for example Quotations to approve, Committee scoring pending, Returned to you, Purchase orders to create, Invoices to review). Click a task to open it. \"All caught up\" means nothing is waiting.",
            "④ Procurement Overview: one line per card showing how many records came each month. Choose Last 6 Months or Last 12 Months; point at a dot for the exact number.",
            "⑤ Status Distribution: your vendor registrations and quotations together by approval status - Approved, In Approval, Returned, Rejected, Not Sent - with count and %.",
            "⑥ Quick Actions: buttons for the work your role allows (Request for Proposal, Add Vendor, Send Registration Link, My Approvals, Finance Queue, Procurement Settings).",
            "⑦ Recent Quotations: QTN number, subject, department, date and the current stage. Click a row to open it.",
            "⑧ Recent Vendor Registrations: VEN number, name, date and status. View all opens the full list.",
            "⑨ Notifications: your latest messages; a coloured dot means unread. View all opens the full list."
          ],
          note: "Admins see the whole system. Other users see only their own records and the work assigned to them, so two users can see different numbers.",
          screenshots: [["manual/v3-dashboard-full.jpg", "The whole Dashboard on one screen. The numbers 1 to 9 match the steps above."]]
        },
        {
          id: "vendor-registration", number: "02", role: "Maker",
          title: "Add a Vendor (Vendor Registration)",
          steps: [
            "Click Add Vendor on the Dashboard, or open Vendor Registration Form > Vendor Registration.",
            "The form has 6 steps shown at the top: Basic Information, Contact and Location, Business Status, Theme and Product Selection, Bank Details, Document Uploads.",
            "Fill the fields of the step. Fields marked with a red * are required.",
            "Click Next. If something is missing or wrong, the step does not change and a red message appears under the field. Correct it and click Next again.",
            "Contact and Location: GST No, PAN No, Email, Mobile No, Address, State, District, Block and PIN No.",
            "Theme and Product Selection: tick one or more themes; products and product types are filtered by your choice.",
            "Bank Details: bank name, account type, account number, IFSC and bank address; upload the cancelled cheque.",
            "Document Uploads: upload the required documents (PDF or image). The MSME certificate is required only when MSME is Yes; Aadhar only for a Proprietor firm.",
            "Click Submit Registration in the bottom bar of the last step.",
            "What you type is saved as a draft in the browser, so it is not lost if the page is closed by mistake."
          ],
          note: "Use Previous to go back to any step. You can also click a finished step in the stepper at the top.",
          screenshots: [
            ["manual/v3-vendor-start.jpg", "1 The 6 steps (done steps get a green tick) · 2 A red * means required · 3 A red message says what is missing; the form stays on this step · 4 Next opens the following step."],
            ["manual/v3-vendor-step2.jpg", "1 Click the State box and type - e.g. \"madh\" · 2 Pick from the short list; District and Block then show only matching places."],
            ["manual/v3-vendor-step6.jpg", "1 Upload each document (PDF or image) · 2 Submit Registration saves the form · 3 Previous goes back to check any step."]
          ]
        },
        {
          id: "vendor-link", number: "03", role: "Maker, Vendor",
          title: "Send a Registration Link to a Vendor",
          steps: [
            "Instead of filling the form yourself, the vendor can fill it. Click Send Registration Link.",
            "Select the stakeholder (if asked) and enter the vendor's 10-digit mobile number.",
            "Click Send SMS Invite. The vendor gets the registration link by SMS, and you get a copy.",
            "The vendor opens the link, verifies the mobile number with OTP and fills the same 6-step form.",
            "After the vendor submits, the registration appears in your Vendor Registration list."
          ],
          note: "An approved vendor can also update their details through the open link; the changes go for approval again.",
          screenshots: [["manual/v3-vendor-invite.jpg", "1 Enter the vendor's 10-digit mobile number · 2 Send SMS Invite sends the registration link."]]
        },
        {
          id: "vendor-approval", number: "04", role: "Maker, Approver",
          title: "Send a Vendor for Approval and Approve It",
          steps: [
            "Maker: open Vendor Registration Form. New registrations show a Send button in the Action column. Click Send to start approval.",
            "The Approval Trail column shows each approver and their status (Pending, Verify, Approved, Returned).",
            "Approver: open My Approvals (or click the task on the Dashboard), open the record and check all details and documents.",
            "Click Approve when everything is correct.",
            "Click Return when the maker must correct something, and write a clear remark.",
            "Click Reject only when the registration must not continue.",
            "Maker: a returned record shows on the Dashboard as \"Vendor registrations returned to you\". Open it, read the remark, click Edit, correct and save; it goes back through the same approval.",
            "Approvers get an SMS and a reminder every morning at 9 AM while an approval is pending with them."
          ],
          note: "Only an approved vendor can be selected in a Request for Proposal. An admin can edit a vendor even after approval.",
          screenshots: [
            ["manual/v3-vendor-index.jpg", "1 Add Vendor Registration opens a new form · 2 Send starts the approval of a new registration · 3 Approval Trail shows each approver and status."],
            ["manual/v3-approvals.jpg", "1 Tabs: Pending (waiting on you), Approved, Returned, Rejected and All."]
          ]
        },
        {
          id: "rfp", number: "05", role: "Maker",
          title: "Create a Request for Proposal (Quotation)",
          steps: [
            "Click Request for Proposal on the Dashboard, or open Quotation Proposal > Request for Proposal.",
            "Step 1 - Quotation Details: choose Quotation Value (Above 10K or Below 10K), Thematic Head (optional), Theme, Quotation Subject (5 to 20 words), Proposal Ending Date and Proposal Remark.",
            "Step 2 - Select Vendors: open the vendor list and tick the vendors. Only approved vendors of the selected theme are shown. See section 06 for how many vendors are needed.",
            "Step 3 - Proposal Items: for each item choose Item Name and Unit, and enter Quantity, Max Rate and Remark. Click Add Item for more rows. Max Rate is internal and is not shown to vendors.",
            "Step 4 - Selection Criteria (optional): pick the criteria the committee will use to score vendors.",
            "Step 5 - Approval Committee: choose only the 1st member. The 2nd member is added automatically by value (COO up to ₹10 lakh, Director above ₹10 lakh) and the 3rd is the Programme Director - Finance.",
            "If you chose a Thematic Head in step 1, the committee panel is not shown; the Thematic Head chooses the 1st member.",
            "Click Save Request for Proposal in the bottom bar."
          ],
          note: "Next works only when the step is complete; errors appear on the same step so you can fix them before moving on.",
          screenshots: [
            ["manual/v3-rfp-step1.jpg", "1 Quotation Value - Above 10K or Below 10K · 2 Thematic Head (optional) - type a name · 3 Theme - type to search · 4 Word counter of the subject (5 to 20 words)."],
            ["manual/v3-rfp-step2.jpg", "1 Open the vendor list and tick vendors; only approved vendors of the theme are shown."],
            ["manual/v3-rfp-step3.jpg", "1 Item Name - type to search (e.g. \"lap\") · 2 Add Item adds another row · 3 Max Rate is internal; vendors do not see it."],
            ["manual/v3-rfp-step5.jpg", "1 Type and choose the 1st member · 2 The 2nd and 3rd members come from the policy · 3 Save Request for Proposal."]
          ]
        },
        {
          id: "vendor-rule", number: "06", role: "Maker",
          title: "How Many Vendors - and the Logic Note",
          steps: [
            "Above 10K: select at least 3 vendors for the normal committee process.",
            "Selecting exactly 2 vendors is not allowed.",
            "You may select only 1 vendor if there is a good reason. A Logic Note field then appears and is required.",
            "Click the blue i next to Logic Note to see the format. Click Use this format to fill it from your request (subject, theme, items, vendor, date).",
            "Replace every [ ] part with the real details. The note must have at least 50 words and no [ ] left.",
            "A single-vendor request goes to the Director only (or the COO, if the admin has set that). There is no Thematic Head and no committee scoring.",
            "Below 10K: the vendor count rule does not apply."
          ],
          note: "The word counter under the Logic Note shows how many words you have written.",
          screenshots: [["manual/v3-rfp-single-vendor.jpg", "1 The blue i shows the Logic Note format · 2 Use this format fills it from your request; then replace every [ ] part."],
            ["manual/v3-rfp-two-vendors.jpg", "1 With 2 vendors (Above 10K) Next is stopped: select 3 or more, or only 1 with a Logic Note."]]
        },
        {
          id: "rfp-approval", number: "07", role: "Maker, Thematic Head, Committee",
          title: "Send the Request for Approval",
          steps: [
            "Open the saved request from Quotation Proposal List (or from the Dashboard).",
            "Without a Thematic Head: click Start Committee Approval. The 3 committee members get an SMS and approve, return or reject from My Approvals.",
            "With a Thematic Head: click Send to Thematic Head. The head opens the request, picks the 1st committee member and chooses:",
            "With Committee - the committee approves first, then the request goes to vendors.",
            "Without Committee - the committee is still created, but the request goes to the vendors at once (by SMS); the committee scores the vendor responses later.",
            "Single vendor: click Send to Director (or Send to COO). Only that person approves.",
            "If an approver returns the request, it shows on your Dashboard as \"Quotations returned to you\". Edit, correct and save to restart approval.",
            "After approval, click Send To Vendor. Each vendor gets the quotation link by SMS, and the maker gets a copy. For Below 10K use Open Direct Form to enter the vendor's quotation yourself."
          ],
          note: "The Currently At line at the top of a request always shows who has to act next.",
          screenshots: [["manual/v3-quotation-list.jpg", "1 Status of each request · 2 Approval Trail - who approved and who is pending."]]
        },
        {
          id: "vendor-response", number: "08", role: "Vendor",
          title: "Vendor Sends the Quotation",
          steps: [
            "The vendor opens the quotation link from the SMS.",
            "The vendor enters the OTP sent to the mobile and clicks Verify OTP.",
            "The vendor enters the Vendor Reference No and, for each item, the Quoted Rate, GST % and remarks.",
            "The vendor fills the commercial terms asked for (payment terms, completion date, warranty, EMD) and accepts the terms and conditions.",
            "The vendor clicks Submit Response and can print the submitted quotation.",
            "The maker can see each vendor's response status on the request."
          ],
          note: "If the OTP expires, click Send New OTP and verify again.",
          screenshots: [["manual/manual-vendor-response.png", "Vendor quotation form after OTP verification."]]
        },
        {
          id: "scoring", number: "09", role: "Committee, Maker",
          title: "Compare, Score and Select the Vendor",
          steps: [
            "When vendors have responded, committee members see \"Committee scoring pending\" on the Dashboard.",
            "Open the request and go to Committee Comparison. Rates, GST, totals and remarks of all vendors are shown side by side.",
            "Enter your marks for each vendor against each criterion and save.",
            "When every member has scored, the vendors are ranked and the top vendor is selected automatically.",
            "Single-vendor requests skip scoring: the vendor is selected when the response comes in.",
            "Use Print Comparison for a printable copy."
          ],
          note: "Top Rank and Best Price badges help you see the leading vendor at a glance.",
          screenshots: [
            ["manual/v3-quotation-show.jpg", "1 Currently at - the stage and who has to act next · 2 Buttons for this stage (Print, Edit, Send...)."],
            ["manual/v3-quotation-comparison.jpg", "Committee Comparison: rates and criteria marks of all vendors side by side."]
          ]
        },
        {
          id: "purchase-order", number: "10", role: "Maker, Vendor",
          title: "Purchase Order",
          steps: [
            "After a vendor is selected, the Dashboard shows \"Purchase orders to create\". Open the request and click Purchase Order.",
            "Check the PO sheet, choose Authorized By and set the last date for the vendor's reply.",
            "Click Print Purchase Order for a copy, then Send to Vendor. The vendor gets the PO link by SMS.",
            "The vendor verifies OTP, reads the PO and chooses Accept, Return or Reject with a remark.",
            "If the vendor returns it, add a reply/update and send again. A vendor can return a PO only once.",
            "Within the quotation validity, Reuse Quote / Direct PO lets you order again at the approved rates by changing only the quantities."
          ],
          note: "Goods Receive opens after the vendor accepts the purchase order.",
          screenshots: [
            ["manual/manual-po-create.png", "Purchase Order page with Authorized By, last date and Send to Vendor."],
            ["manual/manual-po-vendor.png", "Vendor PO page with Accept, Return and Reject."]
          ]
        },
        {
          id: "goods-invoice", number: "11", role: "Maker, Vendor",
          title: "Goods Receive and Invoice",
          steps: [
            "Open the request and click Goods Receive.",
            "For each item received, choose Yes, enter Receive Now Qty (not more than the pending quantity) and whether the original invoice was received.",
            "Click Submit Goods Receive. Items can be received in several rounds.",
            "Each submission sends an invoice upload link to the vendor by SMS.",
            "The vendor verifies OTP, uploads the invoice and submits.",
            "The Dashboard shows \"Invoices to review\". Open the invoice and click Accept Invoice or Return Invoice (with a remark)."
          ],
          note: "Each goods receive round gets its own invoice request, so partial deliveries are easy to follow.",
          screenshots: [
            ["manual/manual-goods-receive.png", "Goods Receive with item-wise quantity."],
            ["manual/manual-invoice-upload.png", "Vendor invoice upload page."],
            ["manual/manual-invoice-review.png", "Maker reviews the invoice: Accept or Return."]
          ]
        },
        {
          id: "finance-assets", number: "12", role: "Maker, Finance",
          title: "Assets, Finance Payment and Payment Advice",
          steps: [
            "After accepting an invoice, click Create Assets when the items are fixed assets and save the asset rows.",
            "Select the accepted invoices, enter PDO No, RFP No and RFP Create Date, and click Move Selected Invoices To Finance.",
            "Finance: open Finance Queue (from the Dashboard), select the invoices and enter Transaction Type, Transaction No and Transaction Date. Save.",
            "Open Payment Advice and click Send Mail to send the payment advice to the vendor."
          ],
          note: "Finance Queue is visible only to finance users and admins.",
          screenshots: [
            ["manual/manual-asset-create.png", "Asset Creation from an accepted invoice."],
            ["manual/manual-payment-reference.png", "PDO / RFP details before moving to finance."],
            ["manual/manual-finance-payment.png", "Finance Payment Queue."]
          ]
        },
        {
          id: "admin", number: "13", role: "Admin",
          title: "Admin Tools",
          steps: [
            "Procurement Settings (sidebar, admins only): choose who approves single-vendor requests - Director (default) or COO - and click Save. It applies to new requests.",
            "Employee Master: keep designations correct (COO, Director, Programme Director - Finance). The committee and approvals use them.",
            "Approval Channels: set who approves vendor registrations and requests for each stakeholder and theme.",
            "Menu Permissions (User Rights): decide which menus each designation can see.",
            "An admin can edit a vendor registration or a request even after approval."
          ],
          note: "If a user cannot see a menu or a task, check their designation, Approval Channel and Menu Permissions.",
          screenshots: [["manual/v3-procurement-settings.jpg", "1 Choose Director (default) or COO for single-vendor requests · 2 Save."]]
        },
        {
          id: "tips", number: "14", role: "All users",
          title: "Useful Tips",
          steps: [
            "Start every day from the Dashboard - \"Needs your action\" tells you what to do.",
            "Every dropdown can be searched: click it and type a few letters (for example \"madh\" for Madhya Pradesh), then pick with the mouse or with the arrow keys and Enter.",
            "Red text under a field explains what is wrong; fix it and continue.",
            "Write clear remarks when you return, reject or reply to a vendor.",
            "Upload readable PDF / JPG / PNG files.",
            "Wait for the green success message before closing the page.",
            "Check the Approval Trail and the Currently At line to know who has to act next."
          ],
          note: "Open this manual any time from User Manual in the sidebar, or download it as PDF.",
          screenshots: [
            ["manual/manual-tips.png", "Full trail of a request: invoice, asset, finance and payment status."]
          ]
        }
      ]
    }
  end

  def hindi
    {
      page_title: "अपूर्ति यूज़र मैनुअल",
      subtitle: "Vendor Registration, Request for Proposal, Approval, Vendor Quotation, Purchase Order, Goods Receive, Invoice और Payment के लिए आसान step-by-step guide.",
      updated_label: "नए flow के अनुसार",
      stakeholder_label: "Stakeholder",
      module_label: "Procurement workflow",
      download_label: "PDF Download",
      contents_label: "विषय सूची",
      note_label: "नोट",
      role_label: "कौन",
      screenshot_label: "स्क्रीन",
      screenshot_note: "स्क्रीन पर click करके बड़ा देखें.",
      quick_flow_title: "पूरा Flow",
      quick_flow: [
        "Login और Dashboard", "Vendor Registration", "Vendor Approval", "Request for Proposal",
        "RFP Approval", "Vendor Quotation", "Scoring और Selection", "Purchase Order",
        "Goods Receive", "Invoice", "Payment और Assets"
      ],
      role_guide_title: "कौन क्या पढ़े",
      role_guide: [
        { role: "Maker", body: "Vendors जोड़ता है, Request for Proposal बनाकर भेजता है, purchase order बनाता है, goods receive करता है और invoice review करता है.", sections: %w[vendor-registration vendor-link vendor-approval rfp vendor-rule rfp-approval purchase-order goods-invoice] },
        { role: "Approver", body: "Vendor registration और requests को check करके approve, return या reject करता है.", sections: %w[vendor-approval rfp-approval] },
        { role: "Committee member", body: "Requests approve करता है और vendors की quotations को marks देता है.", sections: %w[rfp-approval scoring] },
        { role: "Thematic Head", body: "1st committee member और With / Without Committee चुनता है.", sections: %w[rfp-approval] },
        { role: "Vendor", body: "SMS link से registration करता है, quotation भेजता है, purchase order का जवाब देता है और invoice upload करता है.", sections: %w[vendor-link vendor-response purchase-order goods-invoice] },
        { role: "Finance", body: "Accepted invoices का payment दर्ज करता है और payment advice भेजता है.", sections: %w[finance-assets] },
        { role: "Admin", body: "Users, menus, approval channels और Procurement Settings set करता है; approved records भी edit कर सकता है.", sections: %w[admin] }
      ],
      statuses_title: "Status का मतलब",
      statuses: [
        ["Not sent / Not started", "Save है, लेकिन अभी approval में नहीं भेजा.", "slate"],
        ["Pending / In approval", "Approver के action का इंतज़ार.", "amber"],
        ["Returned / Correction by maker", "Maker को ठीक करके फिर save करने के लिए लौटाया गया.", "orange"],
        ["Approved", "सारे approvals हो गए.", "green"],
        ["Rejected", "Approver ने रोक दिया; आगे नहीं बढ़ेगा.", "red"],
        ["Thematic Head decision", "Thematic Head के 1st member और With / Without Committee चुनने का इंतज़ार.", "amber"],
        ["Committee approval", "Committee members request approve कर रहे हैं.", "amber"],
        ["Send to vendors", "Approve हो गया; maker को Send To Vendor दबाना है.", "blue"],
        ["Vendor quotation", "Vendors की quotations का इंतज़ार.", "blue"],
        ["Max rate entry", "Maker को किसी item का छूटा Max Rate भरना है.", "orange"],
        ["Committee scoring", "Committee members को vendors को marks देने हैं.", "purple"],
        ["Vendor selected", "Vendor चुन लिया गया; purchase order बना सकते हैं.", "green"]
      ],
      faq_title: "आम दिक्कतें और उनका हल",
      faqs: [
        ["Next दबाने पर कुछ नहीं होता.", "इस step में कुछ छूटा या गलत है. Field के नीचे लाल message पढ़ें, ठीक करें और फिर Next दबाएं."],
        ["कोई menu या button नहीं दिख रहा.", "Menu और buttons आपके role के अनुसार दिखते हैं. Admin से अपना designation, Menu Permissions और Approval Channel check करवाएं."],
        ["मेरी request की vendor list में vendor नहीं है.", "सिर्फ चुने गए theme के approved vendors दिखते हैं. देखें कि vendor approved है और उसमें वो theme tick है."],
        ["2 vendors नहीं चुन पा रहे.", "Above 10K में 3 या ज़्यादा vendors चाहिए, या सिर्फ 1 vendor Logic Note के साथ. ठीक 2 allowed नहीं है."],
        ["Logic Note accept नहीं हो रहा.", "कम से कम 50 शब्द चाहिए और format का कोई [ ] नहीं बचना चाहिए."],
        ["2nd या 3rd committee member खाली है.", "COO, Director और Programme Director - Finance, Employee Master में इन्हीं designations के साथ होने चाहिए."],
        ["Vendor को OTP नहीं मिला या expire हो गया.", "Mobile number check करें, फिर vendor page पर Send New OTP दबाएं."],
        ["Dropdown में गलत value चुन ली.", "Dropdown पर फिर click करें, कुछ अक्षर लिखें और सही चुनें. Esc से बिना बदलाव list बंद होती है."],
        ["Page पर पुराना data या पुराना look दिख रहा है.", "पूरा reload करने के लिए Ctrl + Shift + R दबाएं."]
      ],
      language_links: [{ code: "en", label: "English" }, { code: "hi", label: "हिंदी" }],
      intro_cards: [
        { title: "Dashboard से शुरू करें", body: "Login के बाद \"Needs your action\" में आपके सारे pending काम दिखते हैं, और Search box (Ctrl + K) से कोई भी quotation, vendor या product खोजें." },
        { title: "हर step खुद check होता है", body: "हर form में Next तभी चलता है जब step पूरा हो. लाल message बताता है क्या ठीक करना है." },
        { title: "Menu आपके role के अनुसार", body: "आपको सिर्फ अपने role के menu दिखते हैं. ज़रूरी menu न दिखे तो admin से कहें." }
      ],
      sections: [
        {
          id: "getting-started", number: "01", role: "सभी users",
          title: "Login और आपका Dashboard",
          steps: [
            "Apurti खोलें और Employee Code और password से login करें. Dashboard खुलता है - नीचे के numbers screen के numbers से मिलते हैं.",
            "① Search: quotation subject, vendor का नाम / firm / mobile / email या product लिखें (कम से कम 2 अक्षर) और Enter दबाएं. Ctrl + K से सीधे search box में पहुंचें. बगल में समय, तारीख, आपका नाम और role है.",
            "② Summary cards - Vendor Registrations, Quotations, Purchase Orders, Approvals. बड़ा number कुल है (Approvals: आपके पास pending); रंगीन dots status के हिसाब से बंटवारा; छोटा graph पिछले महीने; badge पिछले 30 दिन की बढ़त (\"New\" = पहले records पिछले 30 दिन में). Card पर click करके उसकी list खोलें.",
            "③ Needs your action: आप पर pending हर काम गिनती के साथ (जैसे Quotations to approve, Committee scoring pending, Returned to you, Purchase orders to create, Invoices to review). Task पर click करके खोलें. \"All caught up\" = कुछ pending नहीं.",
            "④ Procurement Overview: हर card की एक line - हर महीने कितने records बने. Last 6 Months या Last 12 Months चुनें; सही number के लिए dot पर mouse ले जाएं.",
            "⑤ Status Distribution: आपके vendor registrations और quotations approval status के हिसाब से - Approved, In Approval, Returned, Rejected, Not Sent - गिनती और % के साथ.",
            "⑥ Quick Actions: आपके role के कामों के buttons (Request for Proposal, Add Vendor, Send Registration Link, My Approvals, Finance Queue, Procurement Settings).",
            "⑦ Recent Quotations: QTN number, subject, department, तारीख और अभी का stage. Row पर click करके खोलें.",
            "⑧ Recent Vendor Registrations: VEN number, नाम, तारीख और status. पूरी list के लिए View all.",
            "⑨ Notifications: आपके latest messages; रंगीन dot = unread. View all से पूरी list खुलती है."
          ],
          note: "Admin को पूरा system दिखता है. बाकी users को सिर्फ अपने records और अपने काम दिखते हैं, इसलिए दो users के numbers अलग हो सकते हैं.",
          screenshots: [["manual/v3-dashboard-full.jpg", "पूरा Dashboard एक screen पर. 1 से 9 तक के numbers ऊपर के steps से मिलते हैं."]]
        },
        {
          id: "vendor-registration", number: "02", role: "Maker",
          title: "Vendor जोड़ें (Vendor Registration)",
          steps: [
            "Dashboard पर Add Vendor पर click करें, या Vendor Registration Form > Vendor Registration खोलें.",
            "Form में ऊपर 6 steps दिखते हैं: Basic Information, Contact and Location, Business Status, Theme and Product Selection, Bank Details, Document Uploads.",
            "Step के fields भरें. लाल * वाले fields ज़रूरी हैं.",
            "Next दबाएं. कुछ छूटा या गलत हो तो step नहीं बदलता और field के नीचे लाल message आता है. ठीक करके फिर Next दबाएं.",
            "Contact and Location: GST No, PAN No, Email, Mobile No, Address, State, District, Block और PIN No.",
            "Theme and Product Selection: एक या ज़्यादा theme चुनें; products और product types उसी के अनुसार दिखते हैं.",
            "Bank Details: bank name, account type, account number, IFSC और bank address; cancelled cheque upload करें.",
            "Document Uploads: ज़रूरी documents (PDF या image) upload करें. MSME certificate तभी ज़रूरी है जब MSME Yes हो; Aadhar सिर्फ Proprietor firm के लिए.",
            "आखिरी step की नीचे वाली bar में Submit Registration दबाएं.",
            "आप जो भरते हैं वो browser में draft की तरह save रहता है, गलती से page बंद हो जाए तो भी data नहीं जाता."
          ],
          note: "किसी भी step पर वापस जाने के लिए Previous दबाएं, या ऊपर stepper में पूरा हुआ step click करें.",
          screenshots: [
            ["manual/v3-vendor-start.jpg", "1 6 steps (पूरे step पर हरा tick) · 2 लाल * = ज़रूरी · 3 लाल message बताता है क्या छूटा है; form इसी step पर रहता है · 4 Next से अगला step खुलता है."],
            ["manual/v3-vendor-step2.jpg", "1 State box पर click करके लिखें - जैसे \"madh\" · 2 छोटी list से चुनें; फिर District और Block में सिर्फ उसी के नाम आते हैं."],
            ["manual/v3-vendor-step6.jpg", "1 हर document upload करें (PDF या image) · 2 Submit Registration से form save होता है · 3 Previous से पीछे जाकर कोई भी step देखें."]
          ]
        },
        {
          id: "vendor-link", number: "03", role: "Maker, Vendor",
          title: "Vendor को Registration Link भेजें",
          steps: [
            "Form खुद भरने की जगह vendor से भरवा सकते हैं. Send Registration Link पर click करें.",
            "Stakeholder चुनें (अगर पूछा जाए) और vendor का 10 अंकों का mobile number डालें.",
            "Send SMS Invite दबाएं. Vendor को SMS से link जाता है और आपको भी copy आती है.",
            "Vendor link खोलकर OTP से mobile verify करता है और वही 6-step form भरता है.",
            "Vendor के submit करने के बाद registration आपकी Vendor Registration list में आ जाता है."
          ],
          note: "Approved vendor भी open link से अपनी details update कर सकता है; बदलाव फिर से approval में जाते हैं.",
          screenshots: [["manual/v3-vendor-invite.jpg", "1 Vendor का 10 अंकों का mobile number डालें · 2 Send SMS Invite से registration link जाता है."]]
        },
        {
          id: "vendor-approval", number: "04", role: "Maker, Approver",
          title: "Vendor को Approval में भेजें और Approve करें",
          steps: [
            "Maker: Vendor Registration Form खोलें. नए registration के Action column में Send button होता है. Approval शुरू करने के लिए Send दबाएं.",
            "Approval Trail column में हर approver और उसका status (Pending, Verify, Approved, Returned) दिखता है.",
            "Approver: My Approvals खोलें (या Dashboard का task click करें), record खोलें और सारी details और documents देखें.",
            "सब सही हो तो Approve दबाएं.",
            "Maker को कुछ ठीक करना हो तो Return दबाएं और साफ remark लिखें.",
            "Registration आगे नहीं बढ़ना चाहिए तभी Reject दबाएं.",
            "Maker: लौटाया गया record Dashboard पर \"Vendor registrations returned to you\" में दिखता है. खोलें, remark पढ़ें, Edit करके ठीक करें और save करें; वो उसी approval में वापस जाता है.",
            "Approval pending रहने तक approver को SMS और हर सुबह 9 बजे reminder आता है."
          ],
          note: "Request for Proposal में सिर्फ approved vendor चुना जा सकता है. Admin approval के बाद भी vendor edit कर सकता है.",
          screenshots: [
            ["manual/v3-vendor-index.jpg", "1 Add Vendor Registration से नया form खुलता है · 2 Send से नए registration का approval शुरू होता है · 3 Approval Trail में हर approver और status."],
            ["manual/v3-approvals.jpg", "1 Tabs: Pending (आप पर pending), Approved, Returned, Rejected और All."]
          ]
        },
        {
          id: "rfp", number: "05", role: "Maker",
          title: "Request for Proposal (Quotation) बनाएं",
          steps: [
            "Dashboard पर Request for Proposal दबाएं, या Quotation Proposal > Request for Proposal खोलें.",
            "Step 1 - Quotation Details: Quotation Value (Above 10K या Below 10K), Thematic Head (optional), Theme, Quotation Subject (5 से 20 शब्द), Proposal Ending Date और Proposal Remark भरें.",
            "Step 2 - Select Vendors: vendor list खोलकर vendors tick करें. सिर्फ चुने गए theme के approved vendors दिखते हैं. कितने vendors चाहिए, भाग 06 देखें.",
            "Step 3 - Proposal Items: हर item के लिए Item Name और Unit चुनें, Quantity, Max Rate और Remark भरें. और rows के लिए Add Item दबाएं. Max Rate internal है, vendor को नहीं दिखता.",
            "Step 4 - Selection Criteria (optional): committee जिन criteria पर vendors को marks देगी वो चुनें.",
            "Step 5 - Approval Committee: सिर्फ 1st member चुनें. 2nd member value के हिसाब से अपने आप आता है (₹10 लाख तक COO, उससे ऊपर Director) और 3rd Programme Director - Finance होते हैं.",
            "Step 1 में Thematic Head चुना है तो committee panel नहीं दिखता; 1st member Thematic Head चुनते हैं.",
            "नीचे की bar में Save Request for Proposal दबाएं."
          ],
          note: "Next तभी चलता है जब step पूरा हो; error उसी step पर दिखते हैं ताकि आगे जाने से पहले ठीक कर सकें.",
          screenshots: [
            ["manual/v3-rfp-step1.jpg", "1 Quotation Value - Above 10K या Below 10K · 2 Thematic Head (optional) - नाम लिखें · 3 Theme - लिखकर search करें · 4 Subject का word counter (5 से 20 शब्द)."],
            ["manual/v3-rfp-step2.jpg", "1 Vendor list खोलकर vendors tick करें; सिर्फ theme के approved vendors दिखते हैं."],
            ["manual/v3-rfp-step3.jpg", "1 Item Name - लिखकर search करें (जैसे \"lap\") · 2 Add Item से नई row · 3 Max Rate internal है; vendor को नहीं दिखता."],
            ["manual/v3-rfp-step5.jpg", "1 1st member का नाम लिखकर चुनें · 2 2nd और 3rd member policy से आते हैं · 3 Save Request for Proposal."]
          ]
        },
        {
          id: "vendor-rule", number: "06", role: "Maker",
          title: "कितने Vendors - और Logic Note",
          steps: [
            "Above 10K: normal committee process के लिए कम से कम 3 vendors चुनें.",
            "ठीक 2 vendors चुनना allowed नहीं है.",
            "ठोस कारण हो तो सिर्फ 1 vendor चुन सकते हैं. तब Logic Note field आता है और ज़रूरी होता है.",
            "Logic Note के पास नीले i पर click करके format देखें. Use this format दबाने पर आपकी request (subject, theme, items, vendor, date) से note भर जाता है.",
            "हर [ ] वाले हिस्से में असली details लिखें. Note में कम से कम 50 शब्द हों और कोई [ ] न बचे.",
            "Single vendor request सिर्फ Director के पास जाती है (या COO, अगर admin ने ऐसा set किया है). इसमें Thematic Head और committee scoring नहीं होती.",
            "Below 10K में vendors की गिनती वाला नियम लागू नहीं होता."
          ],
          note: "Logic Note के नीचे का counter बताता है आपने कितने शब्द लिखे हैं.",
          screenshots: [["manual/v3-rfp-single-vendor.jpg", "1 नीला i Logic Note का format दिखाता है · 2 Use this format से आपकी request से भर जाता है; फिर हर [ ] हिस्सा बदलें."],
            ["manual/v3-rfp-two-vendors.jpg", "1 2 vendors (Above 10K) पर Next रुक जाता है: 3 या ज़्यादा चुनें, या सिर्फ 1 Logic Note के साथ."]]
        },
        {
          id: "rfp-approval", number: "07", role: "Maker, Thematic Head, Committee",
          title: "Request को Approval में भेजें",
          steps: [
            "Quotation Proposal List (या Dashboard) से save की गई request खोलें.",
            "Thematic Head के बिना: Start Committee Approval दबाएं. तीनों committee members को SMS जाता है और वो My Approvals से approve, return या reject करते हैं.",
            "Thematic Head के साथ: Send to Thematic Head दबाएं. Head request खोलकर 1st committee member चुनते हैं और चुनते हैं:",
            "With Committee - पहले committee approve करती है, फिर request vendors को जाती है.",
            "Without Committee - committee बनती है, लेकिन request तुरंत vendors को (SMS से) चली जाती है; committee बाद में vendor responses पर marks देती है.",
            "Single vendor: Send to Director (या Send to COO) दबाएं. सिर्फ वही approve करते हैं.",
            "Approver request लौटाए तो वो आपके Dashboard पर \"Quotations returned to you\" में दिखती है. Edit करके ठीक करें और save करें, approval फिर शुरू होगा.",
            "Approval के बाद Send To Vendor दबाएं. हर vendor को SMS से quotation link जाता है और maker को copy आती है. Below 10K में Open Direct Form से vendor की quotation खुद भरें."
          ],
          note: "Request के ऊपर Currently At line हमेशा बताती है कि अगला काम किसका है.",
          screenshots: [["manual/v3-quotation-list.jpg", "1 हर request का status · 2 Approval Trail - किसने approve किया और किस पर pending है."]]
        },
        {
          id: "vendor-response", number: "08", role: "Vendor",
          title: "Vendor Quotation भेजता है",
          steps: [
            "Vendor SMS वाला quotation link खोलता है.",
            "Mobile पर आया OTP डालकर Verify OTP दबाता है.",
            "Vendor Reference No और हर item का Quoted Rate, GST % और remarks भरता है.",
            "मांगी गई commercial terms (payment terms, completion date, warranty, EMD) भरकर terms and conditions accept करता है.",
            "Submit Response दबाता है और submitted quotation print कर सकता है.",
            "Maker request पर हर vendor के response का status देख सकता है."
          ],
          note: "OTP expire हो जाए तो Send New OTP दबाकर फिर verify करें.",
          screenshots: [["manual/manual-vendor-response.png", "OTP verify के बाद vendor quotation form."]]
        },
        {
          id: "scoring", number: "09", role: "Committee, Maker",
          title: "Compare, Score और Vendor Select",
          steps: [
            "Vendors के response आने पर committee members के Dashboard पर \"Committee scoring pending\" दिखता है.",
            "Request खोलकर Committee Comparison पर जाएं. सभी vendors के rates, GST, totals और remarks साथ-साथ दिखते हैं.",
            "हर vendor को हर criterion पर marks दें और save करें.",
            "सभी members के marks देने पर vendors की rank बनती है और top vendor अपने आप select होता है.",
            "Single vendor request में scoring नहीं होती: response आते ही vendor select हो जाता है.",
            "Print करने के लिए Print Comparison दबाएं."
          ],
          note: "Top Rank और Best Price badges से आगे वाला vendor तुरंत दिखता है.",
          screenshots: [
            ["manual/v3-quotation-show.jpg", "1 Currently at - stage और अगला काम किसका है · 2 इस stage के buttons (Print, Edit, Send...)."],
            ["manual/v3-quotation-comparison.jpg", "Committee Comparison: सभी vendors के rates और criteria marks साथ-साथ."]
          ]
        },
        {
          id: "purchase-order", number: "10", role: "Maker, Vendor",
          title: "Purchase Order",
          steps: [
            "Vendor select होने पर Dashboard पर \"Purchase orders to create\" दिखता है. Request खोलकर Purchase Order दबाएं.",
            "PO sheet देखें, Authorized By चुनें और vendor के जवाब की last date डालें.",
            "Copy के लिए Print Purchase Order, फिर Send to Vendor दबाएं. Vendor को SMS से PO link जाता है.",
            "Vendor OTP verify करके PO पढ़ता है और remark के साथ Accept, Return या Reject चुनता है.",
            "Vendor लौटाए तो reply/update लिखकर फिर भेजें. Vendor PO सिर्फ एक बार लौटा सकता है.",
            "Quotation validity के अंदर Reuse Quote / Direct PO से approved rates पर सिर्फ quantity बदलकर फिर order कर सकते हैं."
          ],
          note: "Vendor के PO accept करने के बाद Goods Receive खुलता है.",
          screenshots: [
            ["manual/manual-po-create.png", "Authorized By, last date और Send to Vendor के साथ Purchase Order page."],
            ["manual/manual-po-vendor.png", "Accept, Return और Reject वाला vendor PO page."]
          ]
        },
        {
          id: "goods-invoice", number: "11", role: "Maker, Vendor",
          title: "Goods Receive और Invoice",
          steps: [
            "Request खोलकर Goods Receive दबाएं.",
            "हर मिले item के लिए Yes चुनें, Receive Now Qty डालें (pending quantity से ज़्यादा नहीं) और original invoice मिला या नहीं चुनें.",
            "Submit Goods Receive दबाएं. Items कई बार में receive कर सकते हैं.",
            "हर submission पर vendor को SMS से invoice upload link जाता है.",
            "Vendor OTP verify करके invoice upload और submit करता है.",
            "Dashboard पर \"Invoices to review\" दिखता है. Invoice खोलकर Accept Invoice या Return Invoice (remark के साथ) दबाएं."
          ],
          note: "हर goods receive round की अलग invoice request बनती है, इसलिए partial delivery आसानी से track होती है.",
          screenshots: [
            ["manual/manual-goods-receive.png", "Item-wise quantity के साथ Goods Receive."],
            ["manual/manual-invoice-upload.png", "Vendor invoice upload page."],
            ["manual/manual-invoice-review.png", "Maker invoice review: Accept या Return."]
          ]
        },
        {
          id: "finance-assets", number: "12", role: "Maker, Finance",
          title: "Assets, Finance Payment और Payment Advice",
          steps: [
            "Invoice accept करने के बाद, items fixed asset हों तो Create Assets दबाकर asset rows save करें.",
            "Accepted invoices चुनें, PDO No, RFP No और RFP Create Date भरें और Move Selected Invoices To Finance दबाएं.",
            "Finance: Dashboard से Finance Queue खोलें, invoices चुनें और Transaction Type, Transaction No और Transaction Date भरकर save करें.",
            "Payment Advice खोलकर Send Mail दबाएं, vendor को payment advice चला जाता है."
          ],
          note: "Finance Queue सिर्फ finance users और admin को दिखती है.",
          screenshots: [
            ["manual/manual-asset-create.png", "Accepted invoice से Asset Creation."],
            ["manual/manual-payment-reference.png", "Finance में भेजने से पहले PDO / RFP details."],
            ["manual/manual-finance-payment.png", "Finance Payment Queue."]
          ]
        },
        {
          id: "admin", number: "13", role: "Admin",
          title: "Admin Tools",
          steps: [
            "Procurement Settings (sidebar, सिर्फ admin): single vendor request कौन approve करेगा - Director (default) या COO - चुनकर Save करें. यह नई requests पर लागू होता है.",
            "Employee Master: designations सही रखें (COO, Director, Programme Director - Finance). Committee और approvals इन्हीं से बनते हैं.",
            "Approval Channels: हर stakeholder और theme के लिए vendor registration और requests कौन approve करेगा, set करें.",
            "Menu Permissions (User Rights): हर designation को कौन से menu दिखेंगे, तय करें.",
            "Admin approval के बाद भी vendor registration या request edit कर सकता है."
          ],
          note: "किसी user को menu या task न दिखे तो उसका designation, Approval Channel और Menu Permissions check करें.",
          screenshots: [["manual/v3-procurement-settings.jpg", "1 Single vendor requests के लिए Director (default) या COO चुनें · 2 Save."]]
        },
        {
          id: "tips", number: "14", role: "सभी users",
          title: "काम की बातें",
          steps: [
            "हर दिन Dashboard से शुरू करें - \"Needs your action\" बताता है क्या करना है.",
            "हर dropdown में search कर सकते हैं: click करके कुछ अक्षर लिखें (जैसे Madhya Pradesh के लिए \"madh\"), फिर mouse से या arrow keys और Enter से चुनें.",
            "Field के नीचे लाल text बताता है क्या गलत है; ठीक करके आगे बढ़ें.",
            "Return, reject या vendor को reply करते समय साफ remark लिखें.",
            "साफ PDF / JPG / PNG files upload करें.",
            "Page बंद करने से पहले हरा success message आने दें.",
            "अगला काम किसका है, यह Approval Trail और Currently At line से देखें."
          ],
          note: "यह manual sidebar के User Manual से कभी भी खोलें या PDF download करें.",
          screenshots: [
            ["manual/manual-tips.png", "Request का पूरा trail: invoice, asset, finance और payment status."]
          ]
        }
      ]
    }
  end
end
