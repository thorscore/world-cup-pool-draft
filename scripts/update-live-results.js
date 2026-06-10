const fs = require("fs");
const path = require("path");

const token = process.env.FOOTBALL_DATA_TOKEN;
if (!token) {
  console.log("FOOTBALL_DATA_TOKEN is missing. Add it in GitHub repository secrets to enable live result updates.");
  process.exit(0);
}

const API_URL = "https://api.football-data.org/v4/competitions/WC/matches?season=2026";
const OUT_FILE = path.join(__dirname, "..", "live-results.json");

const STAGE_TO_ROUND = {
  GROUP_STAGE: "group",
  LAST_32: "r32",
  ROUND_OF_32: "r32",
  ROUND_OF_16: "r16",
  QUARTER_FINALS: "qf",
  SEMI_FINALS: "sf",
  FINAL: "final",
  THIRD_PLACE: "final"
};

const TEAM_ALIASES = new Map([
  ["turkiye", "Turkiye"],
  ["turkey", "Turkiye"],
  ["cote d ivoire", "Ivory Coast"],
  ["cote divoire", "Ivory Coast"],
  ["congo dr", "DR Congo"],
  ["dr congo", "DR Congo"],
  ["korea republic", "South Korea"],
  ["republic of korea", "South Korea"],
  ["usa", "United States"],
  ["united states of america", "United States"]
]);

function normalizeName(name) {
  return String(name || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\b(CF|FC|SC|AFC|National Team)\b/gi, "")
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/gi, " ")
    .trim()
    .toLowerCase();
}

function displayName(team) {
  const raw = team?.shortName || team?.tla || team?.name || "";
  return TEAM_ALIASES.get(normalizeName(raw)) || raw;
}

function ensureTeam(results, team) {
  results[team] = results[team] || {};
  return results[team];
}

function addResult(results, team, roundId, outcome) {
  const record = ensureTeam(results, team);
  if (outcome === "win") {
    record[`${roundId}Wins`] = Number(record[`${roundId}Wins`] || 0) + 1;
  }
  if (outcome === "tie") {
    record[`${roundId}Ties`] = Number(record[`${roundId}Ties`] || 0) + 1;
  }
}

async function main() {
  const response = await fetch(API_URL, { headers: { "X-Auth-Token": token } });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`football-data.org returned ${response.status}: ${body.slice(0, 300)}`);
  }

  const data = await response.json();
  const matches = Array.isArray(data.matches) ? data.matches : [];
  const results = {};
  const countedMatches = [];

  for (const match of matches) {
    if (match.status !== "FINISHED") continue;
    const roundId = STAGE_TO_ROUND[match.stage] || "group";
    const home = displayName(match.homeTeam);
    const away = displayName(match.awayTeam);
    if (!home || !away) continue;

    const winner = match.score?.winner;
    if (winner === "HOME_TEAM") {
      addResult(results, home, roundId, "win");
    } else if (winner === "AWAY_TEAM") {
      addResult(results, away, roundId, "win");
    } else if (winner === "DRAW") {
      addResult(results, home, roundId, "tie");
      addResult(results, away, roundId, "tie");
    }

    countedMatches.push({
      id: match.id,
      utcDate: match.utcDate,
      stage: match.stage,
      home,
      away,
      winner: winner || null,
      score: match.score?.fullTime || null
    });
  }

  const output = {
    meta: {
      source: "football-data.org",
      competition: "WC",
      season: 2026,
      updatedAt: new Date().toISOString(),
      finishedMatches: countedMatches.length
    },
    results,
    matches: countedMatches
  };

  fs.writeFileSync(OUT_FILE, `${JSON.stringify(output, null, 2)}\n`);
  console.log(`Wrote ${OUT_FILE} with ${countedMatches.length} finished matches.`);
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
