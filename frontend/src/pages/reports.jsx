import React, { useState, useEffect, useMemo } from "react";
import "../Styles/tailwind.css";
import axios from "axios";
import { normalizeDate, getToday } from "../utils/leadutil";
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, CartesianGrid, Legend, AreaChart, Area } from "recharts";
import { Calendar, Filter, RefreshCw, Search } from "lucide-react";
import { useAuth } from "../auth/AuthContext";
import { API } from "../config";

const COLORS = ["#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#EC4899", "#06B6D4", "#84CC16", "#F97316", "#14B8A6"];
const PIE_COLORS = ["#3B82F6", "#10B981", "#F59E0B", "#8B5CF6", "#EC4899", "#06B6D4"];

const Reports = () => {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState("overview");
  const [teamMembers, setTeamMembers] = useState([]);
  const [sortBy, setSortBy] = useState("leads");
  const [filter, setFilter] = useState("month");
  const [viewMode, setViewMode] = useState("grid");
  const [showCustomDate, setShowCustomDate] = useState(false);
  const [customFromDate, setCustomFromDate] = useState("");
  const [customToDate, setCustomToDate] = useState("");
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  const [overview, setOverview] = useState(null);
  const [employeeData, setEmployeeData] = useState([]);
  const [monthlyTrends, setMonthlyTrends] = useState([]);
  const [breakdownData, setBreakdownData] = useState([]);

  const today = getToday();

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      const token = localStorage.getItem("token");
      const config = { headers: { Authorization: `Bearer ${token}` } };
      const queryParams = `?filter=${filter}${customFromDate ? `&from=${customFromDate}` : ""}${customToDate ? `&to=${customToDate}` : ""}${searchTerm ? `&customer=${searchTerm}` : ""}`;
      const trendsType = filter === 'day' ? 'daily' : filter === 'week' ? 'daily' : filter === 'year' ? 'yearly' : 'monthly';

      try {
        const [team, ov, emp, mt, bd] = await Promise.all([
          axios.get(`${API}/api/teammember`, config),
          axios.get(`${API}/api/reports/overview${queryParams}`, config),
          axios.get(`${API}/api/reports/employee-comparison${queryParams}`, config),
          axios.get(`${API}/api/reports/trends?type=${trendsType}${queryParams}`, config),
          axios.get(`${API}/api/reports/breakdown${queryParams}`, config),
        ]);
        
        setTeamMembers(team.data);
        setOverview(ov.data);
        setEmployeeData(emp.data);
        setMonthlyTrends(mt.data);
        setBreakdownData(bd.data);
        setLoading(false);
      } catch (err) {
        console.error("Fetch error:", err);
        setLoading(false);
      }
    };
    fetchData();
  }, [filter, customFromDate, customToDate, searchTerm]);

  const getStartDate = () => {
    if (showCustomDate && customFromDate) return customFromDate;
    const d = new Date();
    if (filter === "day") return today;
    if (filter === "week") d.setDate(d.getDate() - 6);
    if (filter === "month") d.setDate(1);
    if (filter === "year") { d.setMonth(0); d.setDate(1); }
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
  };

  const getEndDate = () => {
    if (showCustomDate && customToDate) return customToDate;
    return today;
  };

  const startDate = getStartDate();
  const endDate = getEndDate();
  const inRange = (dateStr) => dateStr && normalizeDate(dateStr) >= startDate && normalizeDate(dateStr) <= endDate;

  const handleFilterChange = (newFilter) => {
    setFilter(newFilter);
    setShowCustomDate(false);
    setCustomFromDate("");
    setCustomToDate("");
  };

  const handleCustomDateApply = () => {
    if (customFromDate && customToDate) {
      setShowCustomDate(false);
    }
  };

  const getDateRangeLabel = () => {
    if (showCustomDate && customFromDate && customToDate) {
      return `${customFromDate} to ${customToDate}`;
    }
    if (filter === "day") return "Today";
    if (filter === "week") return "Last 7 Days";
    if (filter === "month") return "This Month";
    if (filter === "year") return "This Year";
    return "This Month";
  };

  const getBreakdownColumnLabel = () => {
    if (filter === "day") return "Day";
    if (filter === "week") return "Week";
    if (filter === "month") return "Month";
    if (filter === "year") return "Year";
    return "Month";
  };

  const getBreakdownData = () => {
    if (breakdownData.length > 0) return breakdownData;
    return monthlyTrends;
  };

  const overviewData = overview || {
    totalSales: 0, totalLeads: 0, totalCalls: 0, totalWalkins: 0, totalFields: 0,
    totalServices: 0, totalRevenue: 0, convertedLeads: 0, totalClients: 0, totalContracts: 0, totalProposals: 0
  };

  const getLeadSourceData = () => [
    { name: "Telecalling", value: overviewData.totalCalls, color: "#3B82F6" },
    { name: "Walkins", value: overviewData.totalWalkins, color: "#10B981" },
    { name: "Field Work", value: overviewData.totalFields, color: "#8B5CF6" },
  ];

  const getConversionData = () => [
    { name: "Converted", value: overviewData.convertedLeads, color: "#10B981" },
    { name: "Not Converted", value: Math.max(0, overviewData.totalLeads - overviewData.convertedLeads), color: "#EF4444" },
  ];

  const getEmployeePerformanceData = () => employeeData.slice(0, 6).map(emp => ({
    name: emp.name.split(" ")[0],
    Leads: emp.totalLeads,
    Revenue: emp.serviceRevenue,
    Conversion: emp.conversionRate,
    Services: emp.services,
  }));

  const OverviewTab = () => (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-4">
        <div className="flex gap-2 bg-gray-100 p-1 rounded-xl w-fit">
          {["day", "week", "month", "year"].map(f => (
            <button key={f} onClick={() => handleFilterChange(f)} className={`px-4 py-2 rounded-lg text-sm font-semibold transition ${filter === f && !showCustomDate ? "bg-white shadow text-blue-600" : "text-gray-500"}`}>
              {f === "day" ? "Day" : f === "week" ? "Week" : f === "month" ? "Month" : "Year"}
            </button>
          ))}
        </div>
        <button
          onClick={() => setShowCustomDate(!showCustomDate)}
          className={`px-4 py-2 rounded-lg text-sm font-semibold transition flex items-center gap-2 ${showCustomDate ? "bg-blue-600 text-white" : "bg-gray-200 text-gray-700"}`}
        >
          <Calendar size={16} /> Custom Date
        </button>
        {showCustomDate && (
          <div className="flex items-center gap-2 bg-white p-2 rounded-lg shadow border">
            <input
              type="date"
              value={customFromDate}
              onChange={(e) => setCustomFromDate(e.target.value)}
              className="border rounded px-2 py-1 text-sm"
            />
            <span className="text-gray-500">to</span>
            <input
              type="date"
              value={customToDate}
              onChange={(e) => setCustomToDate(e.target.value)}
              className="border rounded px-2 py-1 text-sm"
            />
            <button onClick={handleCustomDateApply} className="bg-blue-600 text-white px-3 py-1 rounded text-sm hover:bg-blue-700">Apply</button>
          </div>
        )}
        <div className="ml-auto text-sm text-gray-500 flex items-center gap-4">
          <div className="flex items-center gap-2 bg-white border rounded-lg px-3 py-1.5 shadow-sm">
            <Search size={14} className="text-gray-400" />
            <input 
              type="text" 
              placeholder="Filter by Customer..." 
              value={searchTerm} 
              onChange={(e) => setSearchTerm(e.target.value)}
              className="outline-none text-sm w-40"
            />
          </div>
          <div className="flex items-center gap-2">
            <Calendar size={14} />
            Showing: <span className="font-semibold text-gray-700">{getDateRangeLabel()}</span>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
        <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl p-4 text-white"><p className="text-blue-100 text-sm">Total Sales</p><p className="text-2xl font-bold">₹{overviewData.totalSales.toLocaleString()}</p></div>
        <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-xl p-4 text-white"><p className="text-green-100 text-sm">Total Leads</p><p className="text-2xl font-bold">{overviewData.totalLeads}</p></div>
        <div className="bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl p-4 text-white"><p className="text-purple-100 text-sm">Services Done</p><p className="text-2xl font-bold">{overviewData.totalServices}</p></div>
        <div className="bg-gradient-to-br from-orange-500 to-orange-600 rounded-xl p-4 text-white"><p className="text-orange-100 text-sm">Revenue</p><p className="text-2xl font-bold">₹{overviewData.totalRevenue.toLocaleString()}</p></div>
        <div className="bg-gradient-to-br from-cyan-500 to-cyan-600 rounded-xl p-4 text-white"><p className="text-cyan-100 text-sm">Conversion</p><p className="text-2xl font-bold">{overviewData.totalLeads > 0 ? Math.round((overviewData.convertedLeads / overviewData.totalLeads) * 100) : 0}%</p></div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white rounded-xl shadow-lg p-4">
          <h3 className="text-lg font-semibold text-gray-700 mb-4">Monthly Sales & Leads Trend</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={monthlyTrends}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="name" stroke="#6b7280" fontSize={12} />
              <YAxis yAxisId="left" stroke="#6b7280" fontSize={12} />
              <YAxis yAxisId="right" orientation="right" stroke="#6b7280" fontSize={12} />
              <Tooltip formatter={(value, name) => [name === "Sales" || name === "Revenue" ? `₹${value.toLocaleString()}` : value, name]} />
              <Legend />
              <Line yAxisId="left" type="monotone" dataKey="Sales" stroke="#3B82F6" strokeWidth={3} dot={{ r: 4 }} />
              <Line yAxisId="right" type="monotone" dataKey="Leads" stroke="#10B981" strokeWidth={3} dot={{ r: 4 }} />
              <Line yAxisId="right" type="monotone" dataKey="Services" stroke="#F59E0B" strokeWidth={2} strokeDasharray="5 5" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-white rounded-xl shadow-lg p-4">
          <h3 className="text-lg font-semibold text-gray-700 mb-4">Revenue & Services Trend</h3>
          <ResponsiveContainer width="100%" height={300}>
            <AreaChart data={monthlyTrends}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="name" stroke="#6b7280" fontSize={12} />
              <YAxis stroke="#6b7280" fontSize={12} />
              <Tooltip formatter={(value, name) => [name === "Revenue" ? `₹${value.toLocaleString()}` : value, name]} />
              <Legend />
              <Area type="monotone" dataKey="Revenue" stackId="1" stroke="#8B5CF6" fill="#8B5CF6" fillOpacity={0.6} />
              <Area type="monotone" dataKey="Services" stackId="2" stroke="#EC4899" fill="#EC4899" fillOpacity={0.6} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="bg-white rounded-xl shadow-lg p-4">
          <h3 className="text-lg font-semibold text-gray-700 mb-4">Lead Sources</h3>
          <ResponsiveContainer width="100%" height={250}>
            <PieChart>
              <Pie data={getLeadSourceData()} cx="50%" cy="50%" innerRadius={60} outerRadius={80} paddingAngle={5} dataKey="value" label={({ name, value }) => `${name}: ${value}`}>
                {getLeadSourceData().map((entry, index) => (<Cell key={`cell-${index}`} fill={entry.color} />))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
          <div className="flex justify-center gap-4 mt-2">
            {getLeadSourceData().map((item, i) => (
              <div key={i} className="flex items-center gap-2"><div className="w-3 h-3 rounded-full" style={{ backgroundColor: item.color }}></div><span className="text-sm text-gray-600">{item.name}</span></div>
            ))}
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-lg p-4">
          <h3 className="text-lg font-semibold text-gray-700 mb-4">Lead Conversion</h3>
          <ResponsiveContainer width="100%" height={250}>
            <PieChart>
              <Pie data={getConversionData()} cx="50%" cy="50%" innerRadius={60} outerRadius={80} paddingAngle={5} dataKey="value" label={({ name, value }) => `${name}: ${value}`}>
                {getConversionData().map((entry, index) => (<Cell key={`cell-${index}`} fill={entry.color} />))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
          <div className="flex justify-center gap-4 mt-2">
            {getConversionData().map((item, i) => (
              <div key={i} className="flex items-center gap-2"><div className="w-3 h-3 rounded-full" style={{ backgroundColor: item.color }}></div><span className="text-sm text-gray-600">{item.name}</span></div>
            ))}
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-lg p-4">
          <h3 className="text-lg font-semibold text-gray-700 mb-4">Employee Performance</h3>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={getEmployeePerformanceData()} layout="vertical">
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis type="number" />
              <YAxis dataKey="name" type="category" width={60} />
              <Tooltip />
              <Bar dataKey="Leads" fill="#3B82F6" radius={[0, 4, 4, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white rounded-xl p-4 shadow border"><p className="text-gray-500 text-sm">Telecalls</p><p className="text-2xl font-bold text-blue-600">{overviewData.totalCalls}</p></div>
        <div className="bg-white rounded-xl p-4 shadow border"><p className="text-gray-500 text-sm">Walkins</p><p className="text-2xl font-bold text-green-600">{overviewData.totalWalkins}</p></div>
        <div className="bg-white rounded-xl p-4 shadow border"><p className="text-gray-500 text-sm">Field Visits</p><p className="text-2xl font-bold text-purple-600">{overviewData.totalFields}</p></div>
        <div className="bg-white rounded-xl p-4 shadow border"><p className="text-gray-500 text-sm">Total Clients</p><p className="text-2xl font-bold text-orange-600">{overviewData.totalClients}</p></div>
      </div>

      <div className="bg-white rounded-xl shadow-lg overflow-hidden">
        <div className="p-4 border-b"><h3 className="text-lg font-semibold text-gray-700">Breakdown</h3></div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-600 font-semibold">
              <tr><th className="px-4 py-3 text-left">{getBreakdownColumnLabel()}</th><th className="px-4 py-3 text-right">Sales (₹)</th><th className="px-4 py-3 text-right">Leads</th><th className="px-4 py-3 text-right">Services</th><th className="px-4 py-3 text-right">Converted</th><th className="px-4 py-3 text-right">Revenue (₹)</th></tr>
            </thead>
            <tbody>
              {getBreakdownData().map((m, i) => (
                <tr key={i} className="border-b hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium">{m.name}</td>
                  <td className="px-4 py-3 text-right text-blue-600 font-semibold">₹{(m.Sales || 0).toLocaleString()}</td>
                  <td className="px-4 py-3 text-right">{m.Leads || 0}</td>
                  <td className="px-4 py-3 text-right">{m.Services || 0}</td>
                  <td className="px-4 py-3 text-right"><span className={`px-2 py-1 rounded-full text-xs font-medium ${m.Converted > 0 ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500"}`}>{m.Converted || 0}</span></td>
                  <td className="px-4 py-3 text-right text-purple-600">₹{(m.Revenue || 0).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );

  const EmployeeTab = () => {
    const sortedEmployeeData = [...employeeData].sort((a, b) => {
      if (sortBy === "leads") return b.totalLeads - a.totalLeads;
      if (sortBy === "revenue") return b.serviceRevenue - a.serviceRevenue;
      if (sortBy === "conversion") return b.conversionRate - a.conversionRate;
      if (sortBy === "target") return b.targetRate - a.targetRate;
      if (sortBy === "tasks") return b.tasksCompleted - a.tasksCompleted;
      return b.totalLeads - a.totalLeads;
    });

    const teamSummary = {
      totalEmployees: employeeData.length,
      totalLeads: employeeData.reduce((s, m) => s + m.totalLeads, 0),
      totalConverted: employeeData.reduce((s, m) => s + m.leadsConverted, 0),
      totalRevenue: employeeData.reduce((s, m) => s + m.serviceRevenue, 0),
      avgConversion: employeeData.length > 0 ? Math.round(employeeData.reduce((s, m) => s + m.conversionRate, 0) / employeeData.length) : 0,
    };

    return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-4">
        <div className="flex gap-2 bg-gray-100 p-1 rounded-xl w-fit">
          {["day", "week", "month", "year"].map(f => (
            <button key={f} onClick={() => handleFilterChange(f)} className={`px-4 py-2 rounded-lg text-sm font-semibold transition ${filter === f && !showCustomDate ? "bg-white shadow text-blue-600" : "text-gray-500"}`}>
              {f === "day" ? "Day" : f === "week" ? "Week" : f === "month" ? "Month" : "Year"}
            </button>
          ))}
        </div>
        <button
          onClick={() => setShowCustomDate(!showCustomDate)}
          className={`px-4 py-2 rounded-lg text-sm font-semibold transition flex items-center gap-2 ${showCustomDate ? "bg-blue-600 text-white" : "bg-gray-200 text-gray-700"}`}
        >
          <Calendar size={16} /> Custom Date
        </button>
        {showCustomDate && (
          <div className="flex items-center gap-2 bg-white p-2 rounded-lg shadow border">
            <input
              type="date"
              value={customFromDate}
              onChange={(e) => setCustomFromDate(e.target.value)}
              className="border rounded px-2 py-1 text-sm"
            />
            <span className="text-gray-500">to</span>
            <input
              type="date"
              value={customToDate}
              onChange={(e) => setCustomToDate(e.target.value)}
              className="border rounded px-2 py-1 text-sm"
            />
            <button onClick={handleCustomDateApply} className="bg-blue-600 text-white px-3 py-1 rounded text-sm hover:bg-blue-700">Apply</button>
          </div>
        )}
        <div className="ml-auto text-sm text-gray-500 flex items-center gap-2">
          <Calendar size={14} />
          Showing: <span className="font-semibold text-gray-700">{getDateRangeLabel()}</span>
        </div>
      </div>

      <div className="bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-600 rounded-xl p-6 text-white">
        <h3 className="text-lg font-bold mb-4">Team Performance Summary</h3>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
          <div className="text-center"><p className="text-indigo-200 text-sm">Employees</p><p className="text-2xl font-bold">{teamSummary.totalEmployees}</p></div>
          <div className="text-center"><p className="text-indigo-200 text-sm">Total Leads</p><p className="text-2xl font-bold">{teamSummary.totalLeads}</p></div>
          <div className="text-center"><p className="text-indigo-200 text-sm">Converted</p><p className="text-2xl font-bold">{teamSummary.totalConverted}</p></div>
          <div className="text-center"><p className="text-indigo-200 text-sm">Revenue</p><p className="text-2xl font-bold">₹{teamSummary.totalRevenue.toLocaleString()}</p></div>
          <div className="text-center"><p className="text-indigo-200 text-sm">Avg Conv %</p><p className="text-2xl font-bold">{teamSummary.avgConversion}%</p></div>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-lg overflow-hidden">
        <div className="p-4 border-b flex flex-col sm:flex-row gap-4 items-center justify-between">
          <h3 className="text-lg font-semibold text-gray-700">All Employees Comparison</h3>
          <select value={sortBy} onChange={(e) => setSortBy(e.target.value)} className="border rounded-lg px-3 py-1 text-sm">
            <option value="leads">Sort by Leads</option>
            <option value="revenue">Sort by Revenue</option>
            <option value="conversion">Sort by Conversion</option>
            <option value="target">Sort by Target</option>
            <option value="tasks">Sort by Tasks</option>
          </select>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-600 font-semibold">
              <tr><th className="px-3 py-3 text-left">#</th><th className="px-3 py-3 text-left">Employee</th><th className="px-3 py-3 text-center">Position</th><th className="px-3 py-3 text-right">Tel</th><th className="px-3 py-3 text-right">Walk</th><th className="px-3 py-3 text-right">Field</th><th className="px-3 py-3 text-right">Leads</th><th className="px-3 py-3 text-right">Conv%</th><th className="px-3 py-3 text-right">Clients</th><th className="px-3 py-3 text-right">Services</th><th className="px-3 py-3 text-right">Revenue</th><th className="px-3 py-3 text-right">Target%</th></tr>
            </thead>
            <tbody>
              {sortedEmployeeData.map((emp, i) => (
                <tr key={i} className="border-b hover:bg-gray-50">
                  <td className="px-3 py-3 text-gray-400">{i + 1}</td>
                  <td className="px-3 py-3 font-medium text-blue-600">{emp.name}</td>
                  <td className="px-3 py-3 text-center">{emp.position}</td>
                  <td className="px-3 py-3 text-right">{emp.telecalls}</td>
                  <td className="px-3 py-3 text-right">{emp.walkins}</td>
                  <td className="px-3 py-3 text-right">{emp.fields}</td>
                  <td className="px-3 py-3 text-right font-semibold">{emp.totalLeads}</td>
                  <td className="px-3 py-3 text-right"><span className={`px-2 py-0.5 rounded-full text-xs font-medium ${emp.conversionRate >= 50 ? "bg-green-100 text-green-700" : emp.conversionRate >= 25 ? "bg-yellow-100 text-yellow-700" : "bg-red-100 text-red-700"}`}>{emp.conversionRate}%</span></td>
                  <td className="px-3 py-3 text-right">{emp.clients}</td>
                  <td className="px-3 py-3 text-right">{emp.services}</td>
                  <td className="px-3 py-3 text-right font-semibold text-green-600">₹{emp.serviceRevenue.toLocaleString()}</td>
                  <td className="px-3 py-3 text-right"><span className={`px-2 py-0.5 rounded-full text-xs font-medium ${emp.targetRate >= 100 ? "bg-green-100 text-green-700" : emp.targetRate >= 50 ? "bg-yellow-100 text-yellow-700" : emp.targetRate > 0 ? "bg-red-100 text-red-700" : "bg-gray-100 text-gray-500"}`}>{emp.targetRate}%</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
    );
  };

  if (loading) {
    return (
      <div className="w-full p-4 md:p-6 flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <RefreshCw className="animate-spin w-8 h-8 text-blue-600 mx-auto mb-4" />
          <p className="text-gray-500">Loading reports...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="w-full p-4 md:p-6">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-[#1694CE]">Reports & Analytics</h2>
          <span className="text-sm text-gray-500">Dashboard &gt; Reports</span>
        </div>
        <button onClick={() => window.location.reload()} className="flex items-center gap-2 text-gray-500 hover:text-gray-700">
          <RefreshCw size={16} /> Refresh
        </button>
      </div>

      <div className="bg-white rounded-xl shadow mb-4 overflow-hidden">
        <div className="flex border-b flex-wrap">
          <button onClick={() => setActiveTab("overview")} className={`px-6 py-4 font-medium text-sm ${activeTab === "overview" ? "bg-blue-50 text-blue-600 border-b-2 border-blue-600" : "text-gray-600"}`}>Overview</button>
          <button onClick={() => setActiveTab("byEmployee")} className={`px-6 py-4 font-medium text-sm ${activeTab === "byEmployee" ? "bg-blue-50 text-blue-600 border-b-2 border-blue-600" : "text-gray-600"}`}>By Employee</button>
        </div>
      </div>

      {activeTab === "overview" && <OverviewTab />}
      {activeTab === "byEmployee" && <EmployeeTab />}
    </div>
  );
};

export default Reports;