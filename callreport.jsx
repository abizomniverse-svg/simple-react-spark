import React, { useState, useEffect } from "react";
import "../Styles/tailwind.css";
import { Search, Plus, X, Trash2, Edit, PlusCircle, History, User, Clock, MapPin, Calendar, AlertCircle } from "lucide-react";
import axios from "axios";

const CallReport = () => {
  const [activeTab, setActiveTab] = useState("reports");
  const [open, setOpen] = useState(false);
  const [isEdit, setIsEdit] = useState(false);
  const [editSessionId, setEditSessionId] = useState(null);
  const [reports, setReports] = useState([]);
  const [performance, setPerformance] = useState([]);
  const [searchTerm, setSearchTerm] = useState("");

  // History Modal
  const [historyOpen, setHistoryOpen] = useState(false);
  const [historyStaff, setHistoryStaff] = useState("");
  const [historyData, setHistoryData] = useState([]);

  const fetchReports = async () => {
    try {
      const res = await axios.get("http://localhost:3000/api/call-reports");
      setReports(res.data);
    } catch (err) { console.error(err); }
  };

  const fetchPerformance = async () => {
    try {
      const res = await axios.get("http://localhost:3000/api/call-reports/performance");
      setPerformance(res.data);
    } catch (err) { console.error(err); }
  };

  useEffect(() => {
    fetchReports();
    fetchPerformance();
  }, []);

  // Group reports by session_id for the main table
  const groupedSessions = reports.reduce((acc, report) => {
    const sId = report.session_id || `NOSESS-${report.id}`;
    if (!acc[sId]) {
      acc[sId] = {
        session_id: sId,
        staff_name: report.staff_name,
        report_date: report.report_date,
        total_calls: 0,
        total_duration: 0,
        total_assigned: 0,
        total_km: 0,
        has_exceeded: false,
        clients: [],
        first_call_time: report.start_time,
        last_call_time: report.end_time,
      };
    }
    acc[sId].total_calls += 1;
    acc[sId].total_duration += report.actual_duration || 0;
    acc[sId].total_assigned += report.assigned_time || 0;
    acc[sId].total_km += Number(report.km) || 0;
    if (report.is_exceeded) acc[sId].has_exceeded = true;
    
    // Track overall session time span
    if (report.start_time && (!acc[sId].first_call_time || new Date(report.start_time) < new Date(acc[sId].first_call_time))) {
      acc[sId].first_call_time = report.start_time;
    }
    if (report.end_time && (!acc[sId].last_call_time || new Date(report.end_time) > new Date(acc[sId].last_call_time))) {
      acc[sId].last_call_time = report.end_time;
    }
    
    return acc;
  }, {});

  const sessionList = Object.values(groupedSessions).sort((a, b) => new Date(b.report_date) - new Date(a.report_date));

  // Date filter for history
  const [filterFrom, setFilterFrom] = useState("");
  const [filterTo, setFilterTo] = useState("");

  const localToday = () => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
  };

  const [executiveName, setExecutiveName] = useState("");
  const [staffName, setStaffName] = useState("");
  const [calls, setCalls] = useState([{
    id: Date.now(), client_name: "", location: "", phone: "",
    call_date: localToday(),
    start_time: "", end_time: "", assigned_time: 30,
    actual_duration: 0, is_exceeded: false, service_details: "", remarks: "", km: "",
  }]);

  const addCallRow = () => {
    setCalls([...calls, {
      id: Date.now(), client_name: "", location: "", phone: "",
      call_date: localToday(),
      start_time: "", end_time: "", assigned_time: 30,
      actual_duration: 0, is_exceeded: false, service_details: "", remarks: "", km: "",
    }]);
  };

  const removeCallRow = (id) => {
    if (calls.length > 1) setCalls(calls.filter(c => c.id !== id));
  };

  const updateCallField = (id, field, value) => {
    setCalls(prev => prev.map(c => {
      if (c.id === id) {
        const updated = { ...c, [field]: value };
        if (["start_time", "end_time", "assigned_time"].includes(field)) {
          const start = field === "start_time" ? value : c.start_time;
          const end = field === "end_time" ? value : c.end_time;
          const assigned = field === "assigned_time" ? Number(value) : c.assigned_time;
          if (start && end) {
            // Parse HH:MM time strings
            const [sh, sm] = start.split(":").map(Number);
            const [eh, em] = end.split(":").map(Number);
            const startMins = sh * 60 + sm;
            const endMins = eh * 60 + em;
            const diffMins = endMins - startMins;
            if (!isNaN(diffMins)) {
              updated.actual_duration = diffMins > 0 ? diffMins : 0;
              updated.is_exceeded = updated.actual_duration > assigned;
            }
          }
        }
        return updated;
      }
      return c;
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!staffName.trim()) return alert("Staff Name is required");
    if (calls.some(c => c.is_exceeded && !c.remarks.trim())) return alert("Remarks are mandatory for all exceeded calls!");
    
    try {
      const payload = calls.map((c, idx) => ({
        ...c,
        staff_name: staffName,
        executive_name: executiveName,
        report_date: c.call_date,
        call_sequence: idx + 1,
        complaint: c.service_details,
        km: c.km || null,
        session_id: editSessionId
      }));
      
      await axios.post("http://localhost:3000/api/call-reports", payload);
      alert("Session saved successfully");
      fetchReports(); fetchPerformance(); setOpen(false); resetForm();
    } catch (err) { alert("Error saving data"); }
  };

  const resetForm = () => {
    setExecutiveName("");
    setStaffName("");
    setCalls([{ id: Date.now(), client_name: "", location: "", phone: "", call_date: localToday(), start_time: "", end_time: "", assigned_time: 30, actual_duration: 0, is_exceeded: false, service_details: "", remarks: "", km: "" }]);
    setIsEdit(false); setEditSessionId(null);
  };

  const openEdit = async (session) => {
    try {
      const res = await axios.get(`http://localhost:3000/api/call-reports/session/${session.session_id}`);
      const sessionCalls = res.data;
      
      if (sessionCalls && sessionCalls.length > 0) {
        setStaffName(session.staff_name);
        setExecutiveName(sessionCalls[0].executive_name || "");
        setCalls(sessionCalls.map(c => ({
          id: c.id,
          client_name: c.client_name,
          location: c.location || "",
          phone: c.phone || "",
          call_date: c.report_date ? c.report_date.split("T")[0] : localToday(),
          start_time: c.start_time ? new Date(c.start_time).toTimeString().slice(0, 5) : "",
          end_time: c.end_time ? new Date(c.end_time).toTimeString().slice(0, 5) : "",
          assigned_time: c.assigned_time || 30,
          actual_duration: c.actual_duration || 0,
          is_exceeded: !!c.is_exceeded,
          service_details: c.complaint || "",
          remarks: c.remarks || "",
          km: c.km || "",
        })));
        setEditSessionId(session.session_id);
        setIsEdit(true); 
        setOpen(true);
      }
    } catch (err) { 
      console.error(err); 
      alert("Error loading session data");
    }
  };

  const openStaffHistory = async (name) => {
    try {
      const res = await axios.get("http://localhost:3000/api/call-reports");
      const freshReports = res.data;
      const staffCalls = freshReports.filter(r => r.staff_name === name);
      setHistoryStaff(name);
      setHistoryData(staffCalls);
      setFilterFrom(""); setFilterTo("");
      setHistoryOpen(true);
    } catch (err) { console.error(err); }
  };

  const applyDateFilter = async () => {
    try {
      const params = new URLSearchParams();
      if (filterFrom) params.append("from", filterFrom);
      if (filterTo) params.append("to", filterTo);
      const res = await axios.get(`http://localhost:3000/api/call-reports?${params.toString()}`);
      const staffCalls = res.data.filter(r => r.staff_name === historyStaff);
      setHistoryData(staffCalls);
    } catch (err) { console.error(err); }
  };

  const deleteSession = async (sId) => {
    if (!window.confirm("Delete this entire session?")) return;
    try {
      const sessionReports = reports.filter(r => r.session_id === sId);
      for (const r of sessionReports) {
        await axios.delete(`http://localhost:3000/api/call-reports/${r.id}`);
      }
      fetchReports(); fetchPerformance();
    } catch (err) { console.error(err); }
  };

  const downloadExcel = () => {
    const data = historyData;
    if (!data.length) return alert("No data to export");

    const headers = [
      "Call #", "Client Name", "Date", "Start Time", "End Time",
      "Location", "Duration (min)", "Limit (min)", "Status",
      "KM", "Executive", "Technician", "Work Log", "Remarks"
    ];

    const rows = data.map(h => {
      const startTime = h.start_time ? new Date(h.start_time).toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit'}) : '';
      const endTime = h.end_time ? new Date(h.end_time).toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit'}) : '';
      const date = h.report_date ? new Date(h.report_date).toLocaleDateString('en-IN') : '';
      return [
        h.call_sequence, h.client_name, date, startTime, endTime,
        h.location || '', h.actual_duration, h.assigned_time,
        h.is_exceeded ? 'Exceeded' : 'On-Time',
        h.km || '', h.executive_name || '', historyStaff,
        h.complaint || '', h.remarks || ''
      ];
    });

    // Build CSV (Excel-compatible)
    const csvContent = [headers, ...rows]
      .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(","))
      .join("\n");

    const blob = new Blob(["\uFEFF" + csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `ServiceReport_${historyStaff}_${new Date().toISOString().slice(0,10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const SectionTitle = ({ children }) => (
    <div className="flex items-center gap-2 mb-4 mt-6">
      <div className="h-1 w-6 bg-blue-500 rounded"></div>
      <h3 className="text-sm font-bold text-blue-700 uppercase tracking-wide">{children}</h3>
      <div className="flex-1 h-px bg-blue-100"></div>
    </div>
  );

  return (
    <div className="w-full">
      {/* Header */}
      <div className="invoice-heading-tab flex gap-4 justify-between items-center flex-wrap">
        <div>
          <h2 className="text-2xl font-bold text-[#1694CE]">Call Report</h2>
          <nav className="text-sm text-gray-500">Dashboard &gt; Services &gt; Call Report</nav>
        </div>
        <div className="flex gap-3 flex-wrap">
          <div className="flex bg-gray-100 rounded-lg p-1 border">
            {["reports", "performance"].map((tab) => (
              <button key={tab} onClick={() => setActiveTab(tab)} className={`px-4 py-1.5 rounded-md text-xs font-bold capitalize transition ${activeTab === tab ? "bg-white shadow-sm text-blue-600" : "text-gray-500"}`}>{tab}</button>
            ))}
          </div>
          <div className="flex items-center gap-3 bg-gray-100 px-3 py-1 rounded-lg border h-10 mt-1">
            <Search size={18} className="text-gray-500" />
            <input type="text" placeholder="Search staff..." className="outline-none text-sm w-40 bg-transparent" value={searchTerm} onChange={e => setSearchTerm(e.target.value)} />
          </div>
          <div className="mt-1">
            <button onClick={() => { resetForm(); setOpen(true); }} className="bg-[#FF3355] text-white w-12 h-12 rounded-full flex justify-center items-center shadow-lg hover:bg-[#e62848] transition"><Plus size={24} /></button>
          </div>
        </div>
      </div>

      {activeTab === "reports" ? (
        <div className="bg-white shadow-sm rounded-xl mt-6 overflow-hidden border border-gray-100 overflow-x-auto">
          <table className="w-full text-sm text-center border-collapse min-w-[900px]">
            <thead className="bg-[#f8fafc]">
              <tr className="text-gray-700 font-bold uppercase text-xs border-b border-gray-200">
                <th className="px-4 py-4 border-r text-left">Technician Name</th>
                <th className="px-4 py-4 border-r">Date</th>
                <th className="px-4 py-4 border-r">Calls</th>
                <th className="px-4 py-4 border-r">Assigned Time</th>
                <th className="px-4 py-4 border-r">Duration</th>
                <th className="px-4 py-4 border-r">KM</th>
                <th className="px-4 py-4">Action</th>
              </tr>
            </thead>
            <tbody>
              {sessionList.filter(s => 
                s.staff_name.toLowerCase().includes(searchTerm.toLowerCase())
              ).map(s => (
                <tr key={s.session_id} className={`border-b hover:bg-gray-50 transition ${s.has_exceeded ? "bg-red-50/50" : ""}`}>
                  <td className="px-4 py-4 border-r text-left font-bold text-gray-700 cursor-pointer hover:text-blue-600" onClick={() => openStaffHistory(s.staff_name)}>
                    <div className="flex items-center gap-2">
                      <User size={14} className="text-blue-500" /> {s.staff_name}
                    </div>
                  </td>
                  <td className="px-4 py-4 border-r font-medium text-gray-600">
                    {s.report_date ? new Date(s.report_date).toLocaleDateString('en-IN', {day:'2-digit', month:'short', year:'numeric'}) : "---"}
                  </td>
                  <td className="px-4 py-4 border-r">
                    <span className="bg-blue-100 text-blue-700 px-3 py-1 rounded-full text-[10px] font-black uppercase">{s.total_calls} Calls</span>
                  </td>
                  <td className="px-4 py-4 border-r font-bold text-gray-600">{s.total_assigned}m</td>
                  <td className={`px-4 py-4 border-r font-black ${s.has_exceeded ? "text-red-600" : "text-emerald-600"}`}>{s.total_duration}m</td>
                  <td className="px-4 py-4 border-r font-bold text-gray-600">
                    {s.total_km > 0 ? `${s.total_km} km` : "---"}
                  </td>
                  <td className="px-4 py-4">
                    <div className="flex gap-3 justify-center">
                      <button onClick={() => openEdit(s)} className="text-green-600 hover:text-green-800" title="Manage Session"><Edit size={18} /></button>
                      <button onClick={() => deleteSession(s.session_id)} className="text-red-500 hover:text-red-700" title="Delete Session"><Trash2 size={18} /></button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-6">
          {performance.map((p, idx) => (
            <div key={idx} className="bg-white p-6 rounded-xl border shadow-sm hover:shadow-md transition cursor-pointer" onClick={() => openStaffHistory(p.staff_name)}>
              <div className="flex justify-between items-start mb-4">
                <h3 className="font-bold text-lg text-gray-800">{p.staff_name}</h3>
                <div className="bg-blue-50 p-2 rounded-lg text-blue-600"><History size={20} /></div>
              </div>
              <div className="space-y-4">
                <div>
                  <div className="flex justify-between text-xs font-bold text-gray-500 mb-1"><span>Efficiency</span><span>{p.performance_rating}%</span></div>
                  <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
                    <div className={`h-full transition-all ${p.performance_rating > 80 ? "bg-green-500" : p.performance_rating > 50 ? "bg-blue-500" : "bg-red-500"}`} style={{ width: `${p.performance_rating}%` }}></div>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2 text-center">
                  <div className="bg-gray-50 p-3 rounded-lg"><p className="text-[10px] text-gray-400 font-bold uppercase">Total Calls</p><p className="font-black text-slate-800">{p.total_calls}</p></div>
                  <div className="bg-red-50 p-3 rounded-lg"><p className="text-[10px] text-red-400 font-bold uppercase">Exceeded</p><p className="font-black text-red-600">{p.exceeded_calls}</p></div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Main Session Modal */}
      <div className={`overlay ${open ? "show" : ""} flex justify-center items-start overflow-y-auto pt-10 pb-10`}>
        <div className="bg-white rounded-xl shadow-2xl w-[95%] max-w-4xl p-8 relative">
          <div className="flex justify-between items-center mb-4 border-b pb-4">
            <h2 className="text-2xl font-bold text-gray-800">{isEdit ? "Edit Work Session" : "Create New Session"}</h2>
            <X className="cursor-pointer text-gray-400 hover:text-red-500" onClick={() => setOpen(false)} />
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <SectionTitle>Staff & Session Info</SectionTitle>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="flex flex-col gap-1">
                <label className="text-xs font-bold text-gray-500 uppercase">Executive Name (Sales)</label>
                <input type="text" value={executiveName} onChange={e => setExecutiveName(e.target.value)} className="border rounded-lg px-3 py-2 outline-none text-sm focus:border-blue-500" placeholder="Sales Executive" />
              </div>
              <div className="flex flex-col gap-1">
                <label className="text-xs font-bold text-gray-500 uppercase">Technician Name *</label>
                <input type="text" value={staffName} onChange={e => setStaffName(e.target.value)} required className="border rounded-lg px-3 py-2 outline-none text-sm focus:border-blue-500" placeholder="Staff Name" />
              </div>
            </div>

            <div className="flex justify-between items-center mt-6">
              <SectionTitle>Service Call Breakpoints</SectionTitle>
              <button type="button" onClick={addCallRow} className="bg-blue-50 text-blue-600 px-4 py-1.5 rounded-lg text-sm font-bold flex items-center gap-2 hover:bg-blue-100 transition"><PlusCircle size={16}/> Add Breakpoint</button>
            </div>

            <div className="space-y-6">
              {calls.map((call, idx) => (
                <div key={call.id} className={`p-6 border rounded-xl bg-gray-50/30 relative ${call.is_exceeded ? "border-red-200" : "border-blue-100"}`}>
                  <div className="absolute -left-3 top-4 w-7 h-7 bg-blue-600 text-white rounded-full flex items-center justify-center text-xs font-black shadow-md">{idx + 1}</div>
                  {calls.length > 1 && <button type="button" onClick={() => removeCallRow(call.id)} className="absolute -right-2 -top-2 text-white bg-red-500 rounded-full p-1 shadow-lg hover:bg-red-600 transition"><X size={14}/></button>}
                  
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div className="flex flex-col gap-1">
                      <label className="text-xs font-bold text-gray-500 uppercase">Client Name *</label>
                      <input type="text" value={call.client_name} onChange={e => updateCallField(call.id, "client_name", e.target.value)} required className="border rounded-lg px-3 py-2 outline-none text-sm bg-white" placeholder="Customer" />
                    </div>
                    <div className="flex flex-col gap-1">
                      <label className="text-xs font-bold text-gray-500 uppercase">Call Date</label>
                      <input type="date" value={call.call_date} readOnly className="border rounded-lg px-3 py-2 outline-none text-sm bg-gray-50 cursor-not-allowed text-gray-600" />
                    </div>
                    <div className="flex flex-col gap-1">
                      <label className="text-xs font-bold text-gray-500 uppercase">Start Time</label>
                      <input type="time" value={call.start_time} onChange={e => updateCallField(call.id, "start_time", e.target.value)} className="border rounded-lg px-3 py-2 outline-none text-sm bg-white" />
                    </div>
                    <div className="flex flex-col gap-1">
                      <label className="text-xs font-bold text-gray-500 uppercase">End Time</label>
                      <input type="time" value={call.end_time} onChange={e => updateCallField(call.id, "end_time", e.target.value)} className="border rounded-lg px-3 py-2 outline-none text-sm bg-white" />
                    </div>
                    <div className="flex flex-col gap-1">
                      <label className="text-xs font-bold text-gray-500 uppercase">Assigned Mins</label>
                      <select value={call.assigned_time} onChange={e => updateCallField(call.id, "assigned_time", e.target.value)} className="border rounded-lg px-3 py-2 outline-none text-sm bg-white">
                        <option value={30}>30 Minutes</option>
                        <option value={45}>45 Minutes</option>
                        <option value={60}>60 Minutes</option>
                      </select>
                    </div>
                    <div className="flex flex-col gap-1">
                      <label className="text-xs font-bold text-gray-500 uppercase">Location</label>
                      <input type="text" value={call.location} onChange={e => updateCallField(call.id, "location", e.target.value)} className="border rounded-lg px-3 py-2 outline-none text-sm bg-white" />
                    </div>
                    <div className="flex flex-col gap-1">
                      <label className="text-xs font-bold text-gray-500 uppercase">KM</label>
                      <input type="number" value={call.km} onChange={e => updateCallField(call.id, "km", e.target.value)} className="border rounded-lg px-3 py-2 outline-none text-sm bg-white" placeholder="e.g. 12.5" min="0" step="0.1" />
                    </div>
                    <div className="flex flex-col gap-1">
                      <label className="text-xs font-bold text-gray-500 uppercase text-gray-400">Duration</label>
                      <div className={`px-3 py-2 rounded-lg text-sm font-bold border bg-white ${call.is_exceeded ? "text-red-600 border-red-200" : "text-green-600 border-green-200"}`}>{call.actual_duration}m {call.is_exceeded && "⚠ Exceeded"}</div>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                    <div className="flex flex-col gap-1">
                      <label className="text-xs font-bold text-gray-500 uppercase">Work Log</label>
                      <textarea value={call.service_details} onChange={e => updateCallField(call.id, "service_details", e.target.value)} className="border rounded-lg px-3 py-2 outline-none text-sm bg-white h-20 resize-none" placeholder="Service description" />
                    </div>
                    <div className="flex flex-col gap-1">
                      <label className="text-xs font-bold text-gray-500 uppercase">Remarks {call.is_exceeded && <span className="text-red-500 font-bold">* Required</span>}</label>
                      <textarea value={call.remarks} onChange={e => updateCallField(call.id, "remarks", e.target.value)} required={call.is_exceeded} className="border rounded-lg px-3 py-2 outline-none text-sm bg-white h-20 resize-none" placeholder="Required if exceeded" />
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="flex gap-4 pt-8 border-t mt-6">
              <button type="submit" className="flex-1 bg-blue-600 text-white py-3.5 rounded-lg font-bold hover:bg-blue-700 shadow-lg">{isEdit ? "Update Session" : `Save Session (${calls.length} Calls)`}</button>
              <button type="button" onClick={() => setOpen(false)} className="px-10 py-3.5 border rounded-lg font-bold text-gray-600">Cancel</button>
            </div>
          </form>
        </div>
      </div>

      {/* Staff History Modal */}
      <div className={`overlay ${historyOpen ? "show" : ""} flex justify-center items-start overflow-y-auto pt-10 pb-10`}>
        <div className="bg-white rounded-xl shadow-2xl w-[95%] max-w-5xl p-8 relative min-h-[60vh]">
          <div className="flex justify-between items-center mb-6 border-b pb-4 sticky top-0 bg-white z-10">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-blue-600 rounded-xl flex items-center justify-center text-white shadow-lg"><History size={24} /></div>
              <div><h2 className="text-2xl font-bold text-gray-800">Staff Service History</h2><p className="text-sm text-blue-600 font-bold uppercase tracking-widest">{historyStaff}</p></div>
            </div>
            <div className="flex items-center gap-3 flex-wrap">
              {/* Date filter */}
              <div className="flex items-center gap-2 bg-gray-50 border rounded-lg px-3 py-2">
                <span className="text-xs font-bold text-gray-500">From</span>
                <input type="date" value={filterFrom} onChange={e => setFilterFrom(e.target.value)} className="outline-none text-sm bg-transparent" />
                <span className="text-xs font-bold text-gray-500">To</span>
                <input type="date" value={filterTo} onChange={e => setFilterTo(e.target.value)} className="outline-none text-sm bg-transparent" />
                <button onClick={applyDateFilter} className="bg-blue-600 text-white px-3 py-1 rounded text-xs font-bold hover:bg-blue-700">Filter</button>
                <button onClick={() => { setFilterFrom(""); setFilterTo(""); openStaffHistory(historyStaff); }} className="text-gray-400 hover:text-red-500 text-xs font-bold">Clear</button>
              </div>
              <button onClick={downloadExcel} className="flex items-center gap-2 bg-green-700 text-white px-5 py-2 rounded-lg text-xs font-bold hover:bg-green-800 transition">⬇ Download XL</button>
              <X className="cursor-pointer text-gray-400 hover:text-red-500 ml-2" onClick={() => setHistoryOpen(false)} />
            </div>
          </div>
          <div className="mt-8 space-y-6">
            {historyData.map((h, idx) => (
              <div key={idx} className={`p-5 rounded-xl border transition ${h.is_exceeded ? "bg-red-50/40 border-red-200" : "bg-white border-gray-100 shadow-sm"}`}>
                {/* Header row */}
                <div className="flex items-center gap-3 mb-3">
                  <span className={`px-2 py-0.5 rounded text-[10px] font-black uppercase ${h.is_exceeded ? "bg-red-600 text-white" : "bg-blue-600 text-white"}`}>CALL {h.call_sequence}</span>
                  <h4 className="font-bold text-lg text-gray-800">{h.client_name}</h4>
                  {h.is_exceeded && <span className="ml-auto text-xs font-bold text-red-600 bg-red-100 px-2 py-0.5 rounded-full">⚠ Exceeded</span>}
                </div>

                {/* All details grid */}
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs font-semibold text-gray-500 mb-3 uppercase">
                  <span className="flex items-center gap-1.5"><MapPin size={13} className="text-blue-500" /> {h.location || 'N/A'}</span>
                  <span className="flex items-center gap-1.5"><Calendar size={13} className="text-blue-500" /> {h.report_date ? new Date(h.report_date).toLocaleDateString('en-IN') : '---'}</span>
                  <span className="flex items-center gap-1.5"><Clock size={13} className="text-green-500" /> Start: {h.start_time ? new Date(h.start_time).toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit'}) : '---'}</span>
                  <span className="flex items-center gap-1.5"><Clock size={13} className="text-red-400" /> End: {h.end_time ? new Date(h.end_time).toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit'}) : '---'}</span>
                  <span className="flex items-center gap-1.5"><History size={13} className="text-blue-500" /> Duration: {h.actual_duration}m</span>
                  <span className="flex items-center gap-1.5"><History size={13} className="text-gray-400" /> Limit: {h.assigned_time}m</span>
                  {h.km && <span className="flex items-center gap-1.5">🛣 KM: {h.km}</span>}
                  {h.executive_name && <span className="flex items-center gap-1.5">👤 Exec: {h.executive_name}</span>}
                </div>

                {/* Work log + Remarks */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div className="bg-gray-50 p-3 rounded-lg border border-gray-100 text-sm text-gray-700">
                    <p className="text-[10px] font-black text-gray-400 uppercase mb-1">Work Log / Services Done:</p>
                    <p className="italic">"{h.complaint || 'No work log provided.'}"</p>
                  </div>
                  {h.remarks && (
                    <div className="bg-blue-50/50 p-3 rounded-lg border border-blue-100 text-sm text-blue-800">
                      <p className="text-[10px] font-black text-blue-400 uppercase mb-1">Remarks:</p>
                      <p className="italic">"{h.remarks}"</p>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <style>{`
        .overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.4); backdrop-filter: blur(4px); z-index: 1000; opacity: 0; visibility: hidden; transition: all 0.3s; }
        .overlay.show { opacity: 1; visibility: visible; }
        input:focus, select:focus, textarea:focus { border-color: #3b82f6; }
      `}</style>
    </div>
  );
};

export default CallReport;
