# Scheme corpus sources

`schemes.json` holds 7 real central Government of India agriculture schemes,
compiled from public sources on 2026-09-22:

- PM-KISAN: en.wikipedia.org/wiki/PM_Kisan_Samman_Nidhi
- PMFBY: en.wikipedia.org/wiki/Pradhan_Mantri_Fasal_Bima_Yojana
- Kisan Credit Card: en.wikipedia.org/wiki/Kisan_Credit_Card
- Soil Health Card Scheme: en.wikipedia.org/wiki/Soil_Health_Card_scheme
- e-NAM: en.wikipedia.org/wiki/National_Agriculture_Market
- PMKSY: en.wikipedia.org/wiki/Pradhan_Mantri_Krishi_Sinchai_Yojana
- RKVY: en.wikipedia.org/wiki/Rashtriya_Krishi_Vikas_Yojana

Official government portals (pmkisan.gov.in, pmfby.gov.in, myscheme.gov.in,
soilhealth.dac.gov.in) are JS-rendered single-page apps and don't serve
static content a fetch can extract — Wikipedia's static, citation-backed
articles were the workable alternative for structured facts. `application_url`
on each scheme still points at the *official* government portal, not
Wikipedia, so a farmer using the app always lands on the real source.

**Honesty notes, on purpose:**
- Specific figures (premium rates, subvention percentages, subsidy amounts)
  are exactly the kind of thing that gets revised by budget cycle or by
  state. Every scheme with a numeric figure says so explicitly in its
  `benefits`/`description` text and points the farmer at the official portal
  to confirm the current number before acting on it — the same "estimate,
  not ground truth" honesty pattern used elsewhere in this app (see
  `backend/app/agronomy/soil_status.py`'s N/P/K docstring).
- 2 more schemes (PM-KUSUM, Agriculture Infrastructure Fund) were attempted
  and dropped rather than filled in from memory, because their Wikipedia
  pages 404'd under the titles tried and nothing else fetchable was found in
  the time available. Add them the same way (fetch a real source, cite it
  here) rather than guessing figures.
- This is a small, hand-curated corpus (7 schemes), not a scraped PDF corpus
  as the plan's "collect scheme PDFs" phrasing implies. Each scheme is
  treated as a single retrieval chunk since they're already short, atomic
  profiles (~150-300 words) — splitting them further would add complexity
  without benefit at this corpus size. Scaling this up (state schemes, more
  central schemes, full PDF guidelines) is a natural next step; the
  chunk-embed-retrieve pipeline in `app/rag/` doesn't change to support it,
  only the corpus does.
