import{c as r}from"./createLucideIcon-cSd4UaiI.js";import{p as c}from"./index-MVC4-aGN.js";/**
 * @license lucide-react v0.400.0 - ISC
 *
 * This source code is licensed under the ISC license.
 * See the LICENSE file in the root directory of this source tree.
 */const d=r("ShieldCheck",[["path",{d:"M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z",key:"oel41y"}],["path",{d:"m9 12 2 2 4-4",key:"dzmm74"}]]),p=async(s,a,e,t)=>{const{data:n}=await c.post(`/clubs/${s}/teams/${a}/players/${e}/fitness`,t);return n},y=async(s,a,e)=>{const{data:t}=await c.get(`/clubs/${s}/teams/${a}/players/${e}/fitness`);return t},m=async()=>{const{data:s}=await c.get("/players/me/fitness");return s};export{d as S,m as a,p as c,y as g};
