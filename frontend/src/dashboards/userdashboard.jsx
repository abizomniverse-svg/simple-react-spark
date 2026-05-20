import React, { useState, useEffect } from "react";
import "../Styles/tailwind.css";
import Followup from "../components/followupsummary";
import Remainder from "../components/remaindersummary";
import {
  departmentCount,
  bottomText,
  getToday,
  normalizeDate,
  isThisMonth,
} from "../utils/leadutil";
import axios from "axios";
import { useAuth } from "../auth/AuthContext";
import socket from "../socket/socket";

import { API } from "../config/api";

const API_BACKEND = API;

const Dashboard = () => {
  const { user } = useAuth();
  const [leads, setLeads] = useState([]);
  const [walkins, setWalkins] = useState([]);
  const [fields, setFields] = useState([]);
  const [quotations, setQuotations] = useState([]);
  const [invoices, setInvoices] = useState([]);
  const [payments, setPayments] = useState([]);
  const [clients, setClients] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [taskActivity, setTaskActivity] = useState([]);
  const [targets, setTargets] = useState([]);
  const [amcContracts, setAmcContracts] = useState([]);
  const [callReports, setCallReports] = useState([]);
  const [contracts, setContracts] = useState([]);
  const [estimates, setEstimates] = useState([]);
  const [performaInvoices, setPerformaInvoices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [lastFetch, setLastFetch] = useState(new Date());
  const [activeTelecall, setActiveTelecall] = useState("New");
  const [activeWalkin, setActiveWalkin] = useState("New");
  const [activeField, setActiveField] = useState("New");

  const currentUserName = user?.name || user?.email?.split("@")[0] || "User";
  const userDisplayName = user?.name || currentUserName;
  const today = getToday();

  const fetchAll = async () => {
    setLoading(true);
    try {
      const [t, w, f, quot, inv, pay, cli, task, taskAct, tgt, amc, cr, cont, est, pi] = await Promise.all([
        axios.get(`${API_BACKEND}/api/Telecalls`),
        axios.get(`${API_BACKEND}/api/Walkins`),
        axios.get(`${API_BACKEND}/api/Fields`),
        axios.get(`${API_BACKEND}/api/quotations`),
        axios.get(`${API_BACKEND}/api/invoice`),
        axios.get(`${API_BACKEND}/api/payments`),
        axios.get(`${API_BACKEND}/api/client`),
        axios.get(`${API_BACKEND}/api/task`),
        axios.get(`${API_BACKEND}/api/task/activity`),
        axios.get(`${API_BACKEND}/api/targets`),
        axios.get(`${API_BACKEND}/api/amc`),
        axios.get(`${API_BACKEND}/api/call-reports`),
        axios.get(`${API_BACKEND}/api/contract`),
        axios.get(`${API_BACKEND}/api/estimate`),
        axios.get(`${API_BACKEND}/api/performainvoice`),
      ]);

      setLeads(t.data);
      setWalkins(w.data);
      setFields(f.data);
      setQuotations(quot.data);
      setInvoices(inv.data);
      setPayments(pay.data);
      setClients(cli.data);
      setTasks(task.data);
      setTaskActivity(taskAct.data);
      setTargets(tgt.data);
      setAmcContracts(amc.data);
      setCallReports(cr.data);
      setContracts(cont.data);
      setEstimates(est.data);
      setPerformaInvoices(pi.data);
    } catch (err) {
      console.error("Fetching error:", err);
      try {
        const [t, w, f, quot, inv, pay, cli, task, taskAct, tgt, amc, cr, cont, est, pi] = await Promise.all([
          axios.get("/api/Telecalls"),
          axios.get("/api/Walkins"),
          axios.get("/api/Fields"),
          axios.get("/api/quotations"),
          axios.get("/api/invoice"),
          axios.get("/api/payments"),
          axios.get("/api/client"),
          axios.get("/api/task"),
          axios.get("/api/task/activity"),
          axios.get("/api/targets"),
          axios.get("/api/amc"),
          axios.get("/api/call-reports"),
          axios.get("/api/contract"),
          axios.get("/api/estimate"),
          axios.get("/api/performainvoice"),
        ]);
        setLeads(t.data);
        setWalkins(w.data);
        setFields(f.data);
        setQuotations(quot.data);
        setInvoices(inv.data);
        setPayments(pay.data);
        setClients(cli.data);
        setTasks(task.data);
        setTaskActivity(taskAct.data);
        setTargets(tgt.data);
        setAmcContracts(amc.data);
        setCallReports(cr.data);
        setContracts(cont.data);
        setEstimates(est.data);
        setPerformaInvoices(pi.data);
      } catch (err2) {
        console.error("Fallback also failed:", err2);
      }
    }
    setLoading(false);
    setLastFetch(new Date());
  };

  useEffect(() => { fetchAll(); }, []);

  useEffect(() => {
    const refresh = () => fetchAll();
    window.addEventListener("refresh-dashboard", refresh);
    return () => window.removeEventListener("refresh-dashboard", refresh);
  }, []);

  useEffect(() => {
    const handleChange = () => fetchAll();
    socket.on("data_changed", handleChange);
    return () => socket.off("data_changed", handleChange);
  }, []);

  useEffect(() => {
    const interval = setInterval(() => fetchAll(), 10000);
    return () => clearInterval(interval);
  }, []);

  const todaysTelecallsData = leads.filter(l => normalizeDate(l.call_date) === today);
  const todaysWalkinsData = walkins.filter(w => normalizeDate(w.walkin_date) === today);
  const todaysFieldsData = fields.filter(f => normalizeDate(f.visit_date) === today);

  const telecallToday = departmentCount(todaysTelecallsData, "call_outcome");
  const walkinToday = departmentCount(todaysWalkinsData, "walkin_status");
  const fieldToday = departmentCount(todaysFieldsData, "field_outcome");

  const statusColors = {
    New: { text: "text-orange-500", bg: "bg-orange-500" },
    Converted: { text: "text-green-600", bg: "bg-green-600" },
    Disqualified: { text: "text-red-600", bg: "bg-red-600" },
  };

  const followupNotes = {
    Todays: leads.filter(l => l.followup_required === "Yes" && normalizeDate(l.followup_date) === today && l.followup_notes),
    Due: leads.filter(l => l.followup_required === "Yes" && normalizeDate(l.followup_date) > today && l.followup_notes),
    Overdue: leads.filter(l => l.followup_required === "Yes" && normalizeDate(l.followup_date) < today && l.followup_notes),
  };

  const followupSummary = {
    Todays: followupNotes.Todays.length,
    Due: followupNotes.Due.length,
    Overdue: followupNotes.Overdue.length,
  };

  const remainderNotes = {
    Todays: leads.filter(l => l.reminder_required === "Yes" && normalizeDate(l.reminder_date) === today && l.reminder_notes),
    Due: leads.filter(l => l.reminder_required === "Yes" && normalizeDate(l.reminder_date) > today && l.reminder_notes),
    Overdue: leads.filter(l => l.reminder_required === "Yes" && normalizeDate(l.reminder_date) < today && l.reminder_notes),
  };

  const remainderSummary = {
    Todays: remainderNotes.Todays.length,
    Due: remainderNotes.Due.length,
    Overdue: remainderNotes.Overdue.length,
  };

  const totalLeads = leads.length + walkins.length + fields.length;
  const todaysLeads = todaysTelecallsData.length + todaysWalkinsData.length + todaysFieldsData.length;

  const totalQuotations = quotations.length;
  const totalQuotationValue = quotations.reduce((sum, q) => sum + (Number(q.grand_total) || 0), 0);
  const todaysQuotations = quotations.filter(q => normalizeDate(q.quotation_date) === today).length;

  const totalInvoices = invoices.length;
  const totalInvoiceValue = invoices.reduce((sum, i) => sum + (Number(i.grand_total) || 0), 0);

  const totalPayments = payments.length;
  const totalPaymentAmount = payments.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
  const todaysPayments = payments.filter(p => normalizeDate(p.payment_date) === today).length;

  const totalClients = clients.length;
  const myClients = clients.filter(c => c.created_by === user?.id).length;

  const totalTasksCount = tasks.length;
  const completedTasks = tasks.filter(t => t.project_status === "Completed").length;
  const pendingTasks = tasks.filter(t => t.project_status === "Process").length;
  const taskCompletionRate = totalTasksCount > 0 ? ((completedTasks / totalTasksCount) * 100).toFixed(1) : 0;

  const totalTargets = targets.length;
  const achievedTargets = targets.filter(t => t.achievement >= t.target).length;

  const totalAmcContracts = amcContracts.length;
  const activeAmcContracts = amcContracts.filter(a => a.status === "Active").length;

  const totalCallReports = callReports.length;
  const todaysCallReports = callReports.filter(c => normalizeDate(c.call_date) === today).length;

  const totalContracts = contracts.length;
  const activeContracts = contracts.filter(c => c.status === "Active").length;

  const totalEstimates = estimates.length;
  const totalEstimateValue = estimates.reduce((sum, e) => sum + (Number(e.grand_total) || 0), 0);

  const totalPerformaInvoices = performaInvoices.length;
  const totalPerformaValue = performaInvoices.reduce((sum, p) => sum + (Number(p.grand_total) || 0), 0);
  const todaysPerformaSales = performaInvoices
    .filter(p => normalizeDate(p.invoice_date) === today)
    .reduce((sum, p) => sum + (Number(p.grand_total) || 0), 0);

  if (loading) {
    return (
      <div className="w-full bg-surface p-4 lead-summary-main flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto"></div>
          <p className="text-slate mt-4">Loading your data...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="w-full bg-surface p-4 lead-summary-main">
      <div className="p-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-ink">
              Welcome back,{" "}
              <span className="text-primary">{userDisplayName}</span>
            </h1>
            <p className="text-slate mt-1">Your Personal Dashboard - Live Data</p>
          </div>
          <div className="text-right text-sm text-muted">
            <p>Total Leads: {totalLeads}</p>
            <p>Today's Activity: {todaysLeads}</p>
            <div className="flex items-center justify-end gap-2 mt-1">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-green-500"></span>
              </span>
              <span className="text-green-500 font-medium text-xs">LIVE</span>
              <span className="text-xs">{lastFetch.toLocaleTimeString()}</span>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 p-6">
        <div className="card p-4 text-center">
          <p className="text-xs text-slate">My Sales Today</p>
          <h3 className="text-xl font-semibold text-ink mt-1">₹{todaysPerformaSales.toLocaleString("en-IN", { minimumFractionDigits: 2 })}</h3>
        </div>
        <div className="card p-4 text-center">
          <p className="text-xs text-slate">My Quotations</p>
          <h3 className="text-xl font-semibold text-ink mt-1">{totalQuotations}</h3>
          <p className="text-xs text-muted">₹{totalQuotationValue.toLocaleString("en-IN", { minimumFractionDigits: 0, maximumFractionDigits: 0 })}</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-xs text-slate">My Tasks</p>
          <h3 className="text-xl font-semibold text-ink mt-1">{completedTasks}/{totalTasksCount}</h3>
          <p className="text-xs text-muted">{taskCompletionRate}% complete</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-xs text-slate">My Clients</p>
          <h3 className="text-xl font-semibold text-ink mt-1">{myClients}</h3>
          <p className="text-xs text-muted">{totalClients} total</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-xs text-slate">Payments Received</p>
          <h3 className="text-xl font-semibold text-ink mt-1">₹{totalPaymentAmount.toLocaleString("en-IN", { minimumFractionDigits: 2 })}</h3>
          <p className="text-xs text-muted">{totalPayments} payments</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-xs text-slate">Estimates</p>
          <h3 className="text-xl font-semibold text-ink mt-1">{totalEstimates}</h3>
          <p className="text-xs text-muted">₹{totalEstimateValue.toLocaleString("en-IN", { minimumFractionDigits: 0, maximumFractionDigits: 0 })}</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-xs text-slate">AMC Contracts</p>
          <h3 className="text-xl font-semibold text-ink mt-1">{activeAmcContracts}</h3>
          <p className="text-xs text-muted">{totalAmcContracts} total</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-xs text-slate">Call Reports</p>
          <h3 className="text-xl font-semibold text-ink mt-1">{todaysCallReports}</h3>
          <p className="text-xs text-muted">{totalCallReports} total today</p>
        </div>
      </div>

      <div className="flex mt-10 gap-8 justify-center">
        <div className="w-[45%] card p-8 mr-10">
          <h2 className="text-center text-slate font-semibold text-lg mb-6">Telecalling Summary</h2>
          <div className="flex justify-center gap-10">
            {["New", "Converted", "Disqualified"].map(status => (
              <div key={status} onClick={() => setActiveTelecall(status)} className="cursor-pointer text-center">
                <span className={`reaminder-font ${activeTelecall === status ? statusColors[status].text : "text-gray-700"}`}>{status}</span>
                <span className={`ml-2 text-white px-2 py-1 rounded-[50%] w-10 h-5 text-xs ${statusColors[status].bg}`}>{telecallToday[status]}</span>
                {activeTelecall === status && <div className={`active-line mt-1 ${statusColors[status].bg}`}></div>}
              </div>
            ))}
          </div>
          <div className="border-t w-full mt-6 mb-6"></div>
          <div className="flex justify-center items-center gap-2">
            <div className="w-3 h-3 bg-brand-orange rounded-full"></div>
            <p className="text-slate font-medium text-[15px]">{bottomText(telecallToday[activeTelecall], activeTelecall)}</p>
          </div>
        </div>

        <div className="w-[50%] card p-8">
          <h2 className="text-center text-slate font-semibold text-lg mb-6">Walkin Summary</h2>
          <div className="flex justify-center gap-6">
            {["New", "Converted", "Disqualified"].map(status => (
              <div key={status} onClick={() => setActiveWalkin(status)} className="cursor-pointer text-center">
                <span className={`reaminder-font ${activeWalkin === status ? statusColors[status].text : "text-gray-700"}`}>{status}</span>
                <span className={`ml-2 text-white px-2 py-1 rounded-[50%] w-10 h-5 text-xs ${statusColors[status].bg}`}>{walkinToday[status]}</span>
                {activeWalkin === status && <div className={`active-line mt-1 ${statusColors[status].bg}`}></div>}
              </div>
            ))}
          </div>
          <div className="border-t w-full mt-6 mb-6"></div>
          <div className="flex justify-center items-center gap-2">
            <div className="w-3 h-3 bg-brand-orange rounded-full"></div>
            <p className="text-slate font-medium text-[15px]">{bottomText(walkinToday[activeWalkin], activeWalkin)}</p>
          </div>
        </div>
      </div>

      <div className="justify-items-center mt-10">
        <div className="w-[50%] card p-8">
          <h2 className="text-center text-slate font-semibold text-lg mb-6">Fieldwork Summary</h2>
          <div className="flex justify-center gap-6">
            {["New", "Converted", "Disqualified"].map(status => (
              <div key={status} onClick={() => setActiveField(status)} className="cursor-pointer text-center">
                <span className={`reaminder-font ${activeField === status ? statusColors[status].text : "text-ink"}`}>{status}</span>
                <span className={`ml-2 text-white px-2 py-1 rounded-[50%] w-10 h-5 text-xs ${statusColors[status].bg}`}>{fieldToday[status]}</span>
                {activeField === status && <div className={`active-line mt-1 ${statusColors[status].bg}`}></div>}
              </div>
            ))}
          </div>
          <div className="border-t w-full mt-6 mb-6"></div>
          <div className="flex justify-center items-center gap-2">
            <div className="w-3 h-3 bg-brand-orange rounded-full"></div>
            <p className="text-slate font-medium text-[15px]">{bottomText(fieldToday[activeField], activeField)}</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-6 mt-10 w-full">
        <Remainder data={remainderSummary} notes={remainderNotes} />
        <Followup data={followupSummary} notes={followupNotes} />
      </div>

      <div className="grid grid-cols-2 gap-6 mt-10">
        <div className="card p-6 h-[420px] overflow-y-auto">
          <h3 className="text-[22px] font-medium text-ink mb-6">Recent Tasks</h3>
          {tasks.length === 0 ? (
            <p className="text-sm text-muted">No recent tasks</p>
          ) : (
            tasks.map(t => (
              <div key={t.id} className="flex items-start gap-4 mb-5 p-4 rounded-lg border border-hairline hover:shadow-level-1 transition">
                <div className={`w-1.5 rounded-full ${t.project_status === "Completed" ? "bg-green-500" : t.project_status === "Process" ? "bg-blue-500" : "bg-orange-500"}`}></div>
                <div className="flex-1">
                  <p className="text-sm font-semibold text-ink mb-1">{t.task_title}</p>
                  <p className="text-xs text-muted mb-2">Project: <span className="text-ink">{t.project_name}</span></p>
                  <div className="flex items-center gap-3 text-xs">
                    <span className={`px-2 py-1 rounded-full font-medium ${t.project_priority === "High" ? "bg-red-100 text-red-600" : t.project_priority === "Urgent" ? "bg-red-200 text-red-700" : t.project_priority === "Low" ? "bg-gray-200 text-gray-600" : "bg-blue-100 text-blue-600"}`}>{t.project_priority}</span>
                    {t.staff_name && <span className="text-gray-400">👤 {t.staff_name}</span>}
                  </div>
                </div>
                <span className="text-xs font-medium text-gray-500">{t.project_status}</span>
              </div>
            ))
          )}
        </div>

        <div className="bg-white p-6 rounded-xl shadow h-[420px] overflow-y-auto">
          <h3 className="text-[22px] font-medium text-gray-700 mb-6">Latest Activity</h3>
          {taskActivity.length === 0 ? (
            <p className="text-sm text-gray-400">No recent activity</p>
          ) : (
            taskActivity.map(a => (
              <div key={a.id} className="flex gap-4 mb-6">
                <div className="w-12 h-12 rounded-full bg-blue-200 flex items-center justify-center flex-shrink-0">
                  <svg className="w-7 h-7 text-white" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 12a5 5 0 1 0-5-5 5 5 0 0 0 5 5zm0 2c-4.33 0-8 2.17-8 4v2h16v-2c0-1.83-3.67-4-8-4z" />
                  </svg>
                </div>
                <div className="flex-1">
                  <p className="text-sm text-gray-500 mb-1">
                    <span className="text-blue-600 font-medium">Customer</span>{" "}
                    {new Date(a.created_at).toLocaleString()}
                  </p>
                  <p className="text-sm text-blue-600 mb-3">{a.message}</p>
                  {a.action && (
                    <div className="bg-gray-100 rounded-md px-4 py-2 text-sm w-fit">
                      <span className="font-semibold text-gray-600">Action:</span>{" "}
                      <span className="text-gray-700">{a.action}</span>
                    </div>
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
