import{u as x,b as d,c as h,j as e}from"./index-CodU8c8M.js";import{A as p}from"./arrow-left-DDXrfYj2.js";import{c as i}from"./createLucideIcon-BQ9oWEAi.js";/**
 * @license lucide-react v0.400.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const m=i("Bell",[["path",{d:"M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9",key:"1qo2s2"}],["path",{d:"M10.3 21a1.94 1.94 0 0 0 3.4 0",key:"qgo35s"}]]);/**
 * @license lucide-react v0.400.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const b=i("Search",[["circle",{cx:"11",cy:"11",r:"8",key:"4ej97u"}],["path",{d:"m21 21-4.3-4.3",key:"1qie3q"}]]);function g({title:c,showBack:l=!1,onBack:s}){const a=x(),o=d(),{isDark:t}=h(),r=l||o.key!=="default"&&window.history.length>1,n=()=>{if(s)return s();a(-1)};return e.jsxs("header",{className:"sticky top-0 z-30 flex items-center justify-between px-4 md:px-6 lg:px-8 py-3 md:py-4 bg-transparent max-w-7xl mx-auto w-full",children:[e.jsxs("div",{className:"flex items-center gap-2 md:gap-3",children:[r&&e.jsx("button",{onClick:n,className:`p-2 rounded-full transition-colors ${t?"text-white hover:bg-white/10":"text-black hover:bg-black/5"}`,"aria-label":"Go back",id:"btn-back",children:e.jsx(p,{size:22})}),e.jsx("h1",{className:`font-display text-xl md:text-2xl lg:text-3xl uppercase tracking-wider ${t?"text-white":"text-black"}`,children:c})]}),e.jsxs("div",{className:"flex items-center gap-1 md:gap-2",children:[e.jsx("button",{onClick:()=>a("/app/search"),className:`p-2 md:p-2.5 rounded-full transition-colors ${t?"text-white hover:bg-white/10":"text-black hover:bg-black/5"}`,"aria-label":"Search",id:"btn-search",children:e.jsx(b,{size:22})}),e.jsx("button",{onClick:()=>a("/app/notifications"),className:`p-2 md:p-2.5 rounded-full transition-colors relative ${t?"text-white hover:bg-white/10":"text-black hover:bg-black/5"}`,"aria-label":"Notifications",id:"btn-notifications",children:e.jsx(m,{size:22})})]})]})}export{m as B,b as S,g as T};
