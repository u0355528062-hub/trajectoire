export async function onRequestGet({ request, env }) {
  const url = new URL(request.url);
  const cle = env.CLE_ADMIN;
  if (!cle || url.searchParams.get('cle') !== cle) return new Response('Non autorisé', { status: 401 });

  // KV n'a pas de "list toutes les clés d'un coup" comme Netlify Blobs :
  // on pagine avec un curseur, plafonné à 3000 sessions comme avant.
  const sessions = [];
  let cursor;
  while (sessions.length < 3000) {
    const page = await env.SUIVI.list({ prefix: 's/', cursor, limit: 1000 });
    for (const k of page.keys) {
      if (sessions.length >= 3000) break;
      const v = await env.SUIVI.get(k.name);
      if (v) sessions.push(JSON.parse(v));
    }
    if (page.list_complete) break;
    cursor = page.cursor;
  }

  const jour = Date.now() - 864e5, semaine = Date.now() - 6048e5, mois = Date.now() - 2592e6;
  const joueurs = {};
  for (const s of sessions) {
    const j = joueurs[s.anon_id] || (joueurs[s.anon_id] = { anon_id: s.anon_id, sessions: 0, temps_s: 0,
      premiere: s.debut, derniere: s.fin || s.debut, evenements: 0, saisons_max: 0, generale_max: 0,
      niveau_max: 0, division_max: '', buts: 0, matchs: 0, carrieres: 0, retraites: 0, transferts: 0, version: s.version });
    j.sessions++; j.temps_s += s.duree_s || 0; j.evenements += (s.evenements || []).length;
    j.premiere = Math.min(j.premiere, s.debut); j.derniere = Math.max(j.derniere, s.fin || s.debut);
    for (const e of s.evenements || []) {
      if (e.t === 'carriere_creee') j.carrieres++;
      if (e.t === 'retraite') j.retraites++;
      if (e.t === 'transfert') j.transferts++;
      if (e.saison) j.saisons_max = Math.max(j.saisons_max, e.saison);
      if (e.generale) j.generale_max = Math.max(j.generale_max, e.generale);
      if (e.niveau) j.niveau_max = Math.max(j.niveau_max, e.niveau);
      if (e.buts) j.buts += e.buts;
      if (e.matchs) j.matchs += e.matchs;
      if (e.division) j.division_max = e.division;
    }
  }
  const liste = Object.values(joueurs);
  const evs = sessions.flatMap(s => s.evenements || []);
  const compte = (arr, f) => arr.reduce((a, x) => { const k = f(x) || '—'; a[k] = (a[k] || 0) + 1; return a; }, {});
  const moy = (arr, f) => arr.length ? Math.round(arr.reduce((a, x) => a + (f(x) || 0), 0) / arr.length * 10) / 10 : 0;

  const retention = {};
  for (const e of evs) if (e.t === 'saison_finie' && e.saison) retention[e.saison] = (retention[e.saison] || 0) + 1;

  return new Response(JSON.stringify({
    resume: {
      joueurs_total: liste.length,
      actifs_24h: liste.filter(j => j.derniere > jour).length,
      actifs_7j: liste.filter(j => j.derniere > semaine).length,
      actifs_30j: liste.filter(j => j.derniere > mois).length,
      sessions_total: sessions.length,
      temps_total_heures: Math.round(liste.reduce((a, j) => a + j.temps_s, 0) / 360) / 10,
      duree_moyenne_session_min: Math.round(moy(sessions, s => s.duree_s) / 6) / 10,
      sessions_par_joueur: moy(liste, j => j.sessions),
      temps_moyen_par_joueur_min: Math.round(moy(liste, j => j.temps_s) / 6) / 10,
      carrieres_creees: evs.filter(e => e.t === 'carriere_creee').length,
      retraites: evs.filter(e => e.t === 'retraite').length,
      saisons_jouees: evs.filter(e => e.t === 'saison_finie').length,
    },
    repartitions: {
      postes: compte(evs.filter(e => e.t === 'carriere_creee'), e => e.poste),
      cartes: compte(evs.filter(e => e.t === 'carriere_creee'), e => e.carte),
      divisions: compte(evs.filter(e => e.t === 'saison_finie'), e => e.division),
      versions: compte(sessions, s => s.version),
    },
    progression: {
      retention_par_saison: retention,
      generale_moyenne_fin_saison: moy(evs.filter(e => e.t === 'saison_finie'), e => e.generale),
      generale_max_observee: Math.max(0, ...liste.map(j => j.generale_max)),
      saisons_moyennes_par_joueur: moy(liste, j => j.saisons_max),
    },
    joueurs: liste.sort((a, b) => b.temps_s - a.temps_s).slice(0, 200).map(j => ({
      ...j, temps_min: Math.round(j.temps_s / 6) / 10,
      premiere: new Date(j.premiere).toISOString().slice(0, 16),
      derniere: new Date(j.derniere).toISOString().slice(0, 16),
    })),
  }, null, 2), { headers: { 'content-type': 'application/json; charset=utf-8' } });
}
