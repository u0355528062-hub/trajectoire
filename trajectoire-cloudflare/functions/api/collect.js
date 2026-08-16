const TYPES = ['session','carriere_creee','saison_finie','transfert','retraite','abandon','match','achat','choix'];
const ok = (b, s = 200) => new Response(JSON.stringify(b), { status: s,
  headers: { 'content-type': 'application/json', 'access-control-allow-origin': '*',
             'access-control-allow-headers': 'content-type', 'access-control-allow-methods': 'POST,OPTIONS' } });

// Cloudflare Pages Functions : le nom de la fonction = la méthode HTTP.
export async function onRequestOptions() {
  return ok({});
}

export async function onRequestPost({ request, env }) {
  let c; try { c = await request.json(); } catch { return ok({ ok: false }, 400); }

  const id = /^[a-z0-9]{10,40}$/.test(c.anon_id || '') ? c.anon_id : null;
  const sid = /^[a-z0-9]{10,40}$/.test(c.session_id || '') ? c.session_id : null;
  if (!id || !sid || !Array.isArray(c.evenements)) return ok({ ok: false }, 400);

  // env.SUIVI = le binding KV configuré dans le dashboard Cloudflare (voir instructions)
  const cle = `s/${id}/${sid}`;
  const brut = await env.SUIVI.get(cle);
  const ancien = brut ? JSON.parse(brut) : { anon_id: id, session_id: sid, debut: Date.now(), evenements: [] };

  ancien.fin = Date.now();
  ancien.duree_s = Math.max(0, Math.min(86400, parseInt(c.duree_s) || 0));
  ancien.version = String(c.version || '').slice(0, 12);
  ancien.division = String(c.division || '').slice(0, 8);
  for (const e of c.evenements.slice(0, 60)) {
    if (!TYPES.includes(e.type)) continue;
    const n = v => (v == null || isNaN(v)) ? null : Number(v);
    ancien.evenements.push({ t: e.type, d: Date.now(), saison: n(e.saison), division: String(e.division || '').slice(0, 8),
      poste: String(e.poste || '').slice(0, 4), carte: String(e.carte || '').slice(0, 14), generale: n(e.generale),
      niveau: n(e.niveau_xp), age: n(e.age), matchs: n(e.matchs), buts: n(e.buts), passes: n(e.passes),
      note: n(e.note), rang: n(e.rang), argent: n(e.argent) });
  }
  if (ancien.evenements.length > 500) ancien.evenements = ancien.evenements.slice(-500);
  await env.SUIVI.put(cle, JSON.stringify(ancien));
  return ok({ ok: true });
}
