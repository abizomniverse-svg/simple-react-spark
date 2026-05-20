"use strict";

function esc(v) {
  if (v == null) return "";
  return String(v).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function fmtNum(n) {
  return `Rs. ${Number(n || 0).toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function fmtDate(d) {
  return d ? new Date(d).toLocaleDateString("en-IN", { year: "numeric", month: "short", day: "numeric" }) : "---";
}

const BRANCHES = {
  Bangalore: { name: "Bangalore", address: "14th Main Road, GK Layout, Electronic City Post, Bangalore - 560100", gstin: "29AAHFA7876M1ZM" },
  Chennai: { name: "Chennai", address: "5th Floor, 5CD PM Towers, Dreams Road, Thousand Lights, Chennai - 600006", gstin: "33AAHFA7876M1ZX" },
};

function generateEmailHtml({ invoice, items, type, docNumber, docLabel, companyName, companyEmail, companyPhone, companyWebsite, companyGstin, companyAddress }) {
  const h = invoice;
  const taxRate = h.custom_tax ? Number(h.custom_tax) : h.tax_type === "GST5" ? 5 : h.tax_type === "NONE" || h.tax_type === "Without GST" ? 0 : 18;
  const hasGST = taxRate > 0;
  const hasHSN = (items || []).some((i) => i.hsn_sac);

  const subtotal = Number(h.subtotal || 0);
  const totalDiscount = Number(h.total_discount || 0);
  const totalCGST = Number(h.total_cgst || 0);
  const totalSGST = Number(h.total_sgst || 0);
  const totalIGST = Number(h.total_igst || 0);
  const grandTotal = Number(h.grand_total || 0) || (subtotal - totalDiscount + totalCGST + totalSGST + totalIGST);

  const clientAddr = [h.client_address1, h.client_address2, [h.client_city, h.client_state].filter(Boolean).join(", ")]
    .filter(Boolean)
    .join(", ");
  const clientPin = h.client_pincode ? `, Pin: ${esc(h.client_pincode)}` : "";
  const clientCountry = h.client_country && h.client_country !== "India" ? `, ${esc(h.client_country)}` : "";

  const itemRows = (items || []).map((item, i) => {
    const desc = item.description || "";
    const commaIdx = desc.indexOf(",");
    const productName = commaIdx > -1 ? desc.slice(0, commaIdx).trim() : desc;
    const specDetails = commaIdx > -1 ? desc.slice(commaIdx + 1).trim() : "";
    const qty = Number(item.quantity || 0);
    const price = Number(item.price || 0);
    const lineTotal = qty * price;
    return `<tr>
      <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;font-size:11px;color:#1a1f2e;vertical-align:top;">${i + 1}</td>
      <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;font-size:11px;color:#1a1f2e;vertical-align:top;">
        <strong>${esc(productName)}</strong>
        ${specDetails ? `<div style="font-size:10px;color:#64748b;margin-top:2px;">${esc(specDetails)}</div>` : ""}
      </td>
      <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;font-size:11px;color:#444;vertical-align:top;">${esc(item.brand_model || "---")}</td>
      ${hasHSN ? `<td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;font-size:11px;color:#444;vertical-align:top;">${esc(item.hsn_sac || "---")}</td>` : ""}
      <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;font-size:11px;color:#1a1f2e;vertical-align:top;text-align:center;">${qty}</td>
      <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;font-size:11px;color:#1a1f2e;vertical-align:top;">${esc(item.uom || "Nos")}</td>
      ${hasGST ? `<td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;font-size:11px;color:#444;vertical-align:top;text-align:right;">${item.tax || taxRate}%</td>` : ""}
      <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;font-size:11px;color:#444;vertical-align:top;text-align:right;">${fmtNum(price)}</td>
      <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;font-size:11px;color:#1a1f2e;vertical-align:top;text-align:right;"><strong>${fmtNum(lineTotal)}</strong></td>
    </tr>`;
  }).join("");

  const summaryRows = `
    <tr><td style="padding:10px 8px;font-size:12px;color:#64748b;width:50%;">Subtotal</td><td style="padding:10px 8px;font-size:12px;color:#1a1f2e;text-align:right;font-weight:700;width:50%;">${fmtNum(subtotal)}</td></tr>
    ${totalDiscount > 0 ? `<tr><td style="padding:10px 8px;font-size:12px;color:#64748b;width:50%;">Discount</td><td style="padding:10px 8px;font-size:12px;color:#1a1f2e;text-align:right;font-weight:700;width:50%;">${fmtNum(totalDiscount)}</td></tr>` : ""}
    ${totalCGST > 0 ? `<tr><td style="padding:10px 8px;font-size:12px;color:#64748b;width:50%;">CGST (${taxRate / 2}%)</td><td style="padding:10px 8px;font-size:12px;color:#1a1f2e;text-align:right;font-weight:700;width:50%;">${fmtNum(totalCGST)}</td></tr>` : ""}
    ${totalSGST > 0 ? `<tr><td style="padding:10px 8px;font-size:12px;color:#64748b;width:50%;">SGST (${taxRate / 2}%)</td><td style="padding:10px 8px;font-size:12px;color:#1a1f2e;text-align:right;font-weight:700;width:50%;">${fmtNum(totalSGST)}</td></tr>` : ""}
    ${totalIGST > 0 ? `<tr><td style="padding:10px 8px;font-size:12px;color:#64748b;width:50%;">IGST (${taxRate}%)</td><td style="padding:10px 8px;font-size:12px;color:#1a1f2e;text-align:right;font-weight:700;width:50%;">${fmtNum(totalIGST)}</td></tr>` : ""}
    <tr><td style="padding:10px 8px;font-size:14px;color:#1e3a8a;font-weight:700;background:#f0f4ff;width:50%;">GRAND TOTAL</td><td style="padding:10px 8px;font-size:14px;color:#1e3a8a;text-align:right;font-weight:700;background:#f0f4ff;width:50%;">${fmtNum(grandTotal)}</td></tr>`;

  const bank = {
    company: esc(h.bank_company || "ACHME COMMUNICATION"),
    bank: esc(h.bank_name || "HDFC BANK"),
    account: esc(h.bank_account || "00312320005822"),
    ifsc: esc(h.bank_ifsc || "HDFC0000031"),
    branch: esc(h.bank_branch || "Coimbatore"),
  };

  const terms = [];
  if (h.terms_general) terms.push("General Terms & Conditions apply.");
  if (h.terms_tax) terms.push("Prices quoted are exclusive of Sales and Service Tax.");
  if (h.terms_project_period) terms.push(`Project Period: ${esc(h.terms_project_period)}`);
  if (h.terms_validity) terms.push(`Quote valid for ${esc(h.terms_validity)} from quotation date.`);
  try {
    const so = typeof h.terms_separate_orders === "string" ? JSON.parse(h.terms_separate_orders) : (h.terms_separate_orders || {});
    if (so.material) terms.push("A. Material Supply (As per actuals)");
    if (so.installation) terms.push("B. Installation / Services");
    if (so.usd) terms.push("C. Price may vary based on USD rates");
    if (so.boq) terms.push("D. Factory BOQ may vary");
  } catch (_) {}
  if (h.terms_payment) {
    const pt = h.terms_payment === "Custom" ? h.terms_payment_custom : h.terms_payment;
    if (pt) terms.push(`Payment Terms: ${esc(pt)}`);
  }
  if (h.terms_payment_custom && h.terms_payment !== "Custom") terms.push(`Payment Terms: ${esc(h.terms_payment_custom)}`);
  if (h.terms_warranty) terms.push(`Warranty: ${esc(h.terms_warranty)}`);
  if (h.custom_terms) terms.push(esc(h.custom_terms));

  const termsHtml = terms.length > 0 ? `
    <div style="border:1px solid #cbd5e1;border-radius:10px;padding:12px;margin-bottom:14px;">
      <div style="color:#1e3a8a;font-weight:700;font-size:13px;margin-bottom:8px;">TERMS &amp; CONDITIONS</div>
      <ul style="padding-left:18px;margin:0;font-size:11.5px;line-height:1.55;color:#1a1f2e;">
        ${terms.map((t) => `<li style="margin-bottom:4px;">${t}</li>`).join("")}
      </ul>
    </div>` : "";

  const otherBranches = Object.entries(BRANCHES)
    .filter(([key]) => key !== h.supplier_branch)
    .map(([, v]) => v);

  const branchesHtml = otherBranches.length > 0 ? `
    <div style="border:1px solid #cbd5e1;border-radius:10px;padding:12px;margin-bottom:14px;">
      <div style="color:#1e3a8a;font-weight:700;font-size:13px;margin-bottom:8px;">OUR BRANCHES</div>
      <div style="font-size:11.5px;line-height:1.55;color:#1a1f2e;">
        ${otherBranches.map((b) => `<div style="margin-bottom:4px;"><strong>${esc(b.name)}:</strong> ${esc(b.address)} | <strong>GSTIN:</strong> ${esc(b.gstin)}</div>`).join("")}
      </div>
    </div>` : "";

  const execName = esc(h.exec_name || "KRISHNA KUMAR M");
  const execPhone = esc(h.exec_phone || "9842235515");
  const execEmail = h.exec_email ? esc(h.exec_email) : "";

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>${esc(docLabel)} - ${esc(docNumber)}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:'Poppins',Arial,sans-serif;">
  <div style="max-width:700px;margin:20px auto;background:#fff;border:1px solid #cbd5e1;border-radius:10px;overflow:hidden;box-shadow:0 16px 48px rgba(30,41,59,.14);">
    <!-- Top gradient bar -->
    <div style="height:6px;background:linear-gradient(to right,#1f0779e0,#340285,#1b03a1);"></div>

    <!-- Header -->
    <div style="display:grid;grid-template-columns:1fr auto;gap:18px;align-items:start;padding:18px;border-bottom:3px solid #1e3a8a;">
      <div>
        <h1 style="color:#1e3a8a;font-size:20px;font-weight:500;margin:0;">${esc(companyName || "Achme Communication")}</h1>
        <div style="color:#64748b;font-size:11px;font-weight:600;">GSTIN: ${esc(companyGstin || "33AAHFA7876M1ZX")}</div>
        <div style="color:#1a1f2e;font-size:11.5px;line-height:1.55;margin-top:4px;">${esc(companyAddress || "Opp to SMS Hotel, Peelamedu, Avinashi Road, Coimbatore-641004")}</div>
        <div style="color:#1a1f2e;font-size:11.5px;margin-top:4px;">Ph: ${esc(companyPhone || "0422-2569966, 4376555")} | Email: ${esc(companyEmail || "info@achmecommunication.com")}</div>
      </div>
      <div style="text-align:right;">
        <h2 style="color:#1e3a8a;font-size:18px;font-weight:500;margin:0;">${esc(docLabel)}</h2>
        <div style="display:inline-block;border:1px solid #cbd5e1;border-radius:8px;padding:8px 12px;background:#f8fafc;color:#64748b;font-size:12px;margin-top:8px;">
          <span style="color:#1a1f2e;font-weight:600;">Doc No:</span> ${esc(docNumber)}<br>
          <span style="color:#1a1f2e;font-weight:600;">Date:</span> ${fmtDate(h.invoice_date || h.quotation_date || h.estimate_date)}
        </div>
      </div>
    </div>

    <!-- Billed To -->
    <div style="padding:18px;border-bottom:1px solid #e2e8f0;">
      <div style="color:#1e3a8a;font-weight:700;font-size:13px;margin-bottom:8px;">BILLED TO</div>
      <div style="font-size:15px;font-weight:700;color:#2c2c2c;">${esc(h.customer_name || "---")}</div>
      ${h.client_company ? `<div style="font-size:11.5px;color:#444;">${esc(h.client_company)}</div>` : ""}
      ${h.mobile_number ? `<div style="font-size:11.5px;color:#1a1f2e;margin-top:4px;">Ph: ${esc(h.mobile_number)}</div>` : ""}
      ${h.email ? `<div style="font-size:11.5px;color:#1a1f2e;">Email: ${esc(h.email)}</div>` : ""}
      ${h.gst_number ? `<div style="font-size:11.5px;color:#1a1f2e;">GSTIN: ${esc(h.gst_number)}</div>` : ""}
      ${(clientAddr || h.client_pincode) ? `<div style="font-size:11.5px;color:#1a1f2e;margin-top:4px;">${esc(clientAddr)}${clientPin}${clientCountry}</div>` : ""}
    </div>

    <!-- Items Table -->
    <div style="padding:18px;">
      <table style="width:100%;border-collapse:collapse;font-family:'Poppins',Arial,sans-serif;">
        <thead>
          <tr style="background:#f8fafc;">
            <th style="padding:10px 8px;border-bottom:2px solid #1e3a8a;color:#1e293b;font-size:10.5px;font-weight:700;text-align:left;">S.NO</th>
            <th style="padding:10px 8px;border-bottom:2px solid #1e3a8a;color:#1e293b;font-size:10.5px;font-weight:700;text-align:left;">DESCRIPTION</th>
            <th style="padding:10px 8px;border-bottom:2px solid #1e3a8a;color:#1e293b;font-size:10.5px;font-weight:700;text-align:left;">BRAND / MODEL</th>
            ${hasHSN ? '<th style="padding:10px 8px;border-bottom:2px solid #1e3a8a;color:#1e293b;font-size:10.5px;font-weight:700;text-align:left;">HSN/SAC</th>' : ""}
            <th style="padding:10px 8px;border-bottom:2px solid #1e3a8a;color:#1e293b;font-size:10.5px;font-weight:700;text-align:center;">QTY</th>
            <th style="padding:10px 8px;border-bottom:2px solid #1e3a8a;color:#1e293b;font-size:10.5px;font-weight:700;">UOM</th>
            ${hasGST ? '<th style="padding:10px 8px;border-bottom:2px solid #1e3a8a;color:#1e293b;font-size:10.5px;font-weight:700;text-align:right;">GST%</th>' : ""}
            <th style="padding:10px 8px;border-bottom:2px solid #1e3a8a;color:#1e293b;font-size:10.5px;font-weight:700;text-align:right;">PRICE</th>
            <th style="padding:10px 8px;border-bottom:2px solid #1e3a8a;color:#1e293b;font-size:10.5px;font-weight:700;text-align:right;">TOTAL</th>
          </tr>
        </thead>
        <tbody>${itemRows}</tbody>
      </table>

      <!-- Summary -->
      <div style="display:flex;justify-content:flex-end;margin-top:12px;">
        <table style="min-width:280px;border-collapse:collapse;border:1px solid #cbd5e1;border-radius:10px;overflow:hidden;font-family:'Poppins',Arial,sans-serif;">
          <tbody>${summaryRows}</tbody>
        </table>
      </div>
    </div>

    <!-- Terms & Branches -->
    <div style="padding:0 18px 18px;">
      ${termsHtml}
      ${branchesHtml}
    </div>

    <!-- Bank Details -->
    <div style="padding:0 18px 18px;">
      <div style="border:1px solid #cbd5e1;border-radius:10px;padding:14px;">
        <div style="color:#1e3a8a;font-weight:700;font-size:13px;margin-bottom:8px;">BANK DETAILS</div>
        <div style="display:grid;grid-template-columns:88px 1fr;gap:7px 10px;font-size:11.5px;line-height:1.55;">
          <div style="color:#64748b;">Company</div><div style="font-weight:700;">${bank.company}</div>
          <div style="color:#64748b;">Bank</div><div style="font-weight:700;">${bank.bank}</div>
          <div style="color:#64748b;">Account</div><div style="font-weight:700;">${bank.account}</div>
          <div style="color:#64748b;">IFSC</div><div style="font-weight:700;">${bank.ifsc}</div>
          <div style="color:#64748b;">Branch</div><div style="font-weight:700;">${bank.branch}</div>
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div style="background:#f8fafc;padding:12px 18px;border-top:1px solid #e2e8f0;display:flex;flex-wrap:wrap;gap:8px 20px;justify-content:flex-end;align-items:center;font-size:11.5px;line-height:1.55;">
      <div><span style="color:#1e3a8a;font-weight:600;">Executive:</span> ${execName}</div>
      <div><span style="color:#1e3a8a;font-weight:600;">PH:</span> ${execPhone}</div>
      ${execEmail ? `<div><span style="color:#1e3a8a;font-weight:600;">Email:</span> ${execEmail}</div>` : ""}
    </div>
  </div>
</body>
</html>`;
}

module.exports = { generateEmailHtml };
