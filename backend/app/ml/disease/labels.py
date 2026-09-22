"""The 28 classes the disease model predicts, plus a farmer-facing knowledge
base per class (crop, plain-language name, description, symptoms, recommendation).

Model: `asafe51/plantdoc-disease-classifier` — a ViT fine-tuned on **PlantDoc**
(~2,600 real in-field photographs), not PlantVillage (54,000 lab photos on
plain backgrounds). That distinction is the whole point: see
docs/IMPLEMENTATION_PLAN.md §1.1 on domain shift, and the measured comparison
in backend/notebooks/disease_field_eval.json.

Unlike the previous checkpoint, this model publishes a proper `id2label` map
in its config, so class names come straight from the model at load time —
there is no class-order guessing anywhere in this module any more. The keys
below are that published vocabulary, verbatim.
"""

# Verbatim from the model's own config.id2label (28 classes, 13 crops).
PLANT_DISEASE_CLASSES: list[str] = [
    "Apple Scab Leaf",
    "Apple leaf",
    "Apple rust leaf",
    "Bell_pepper leaf",
    "Bell_pepper leaf spot",
    "Blueberry leaf",
    "Cherry leaf",
    "Corn Gray leaf spot",
    "Corn leaf blight",
    "Corn rust leaf",
    "Peach leaf",
    "Potato leaf early blight",
    "Potato leaf late blight",
    "Raspberry leaf",
    "Soyabean leaf",
    "Squash Powdery mildew leaf",
    "Strawberry leaf",
    "Tomato Early blight leaf",
    "Tomato Septoria leaf spot",
    "Tomato leaf",
    "Tomato leaf bacterial spot",
    "Tomato leaf late blight",
    "Tomato leaf mosaic virus",
    "Tomato leaf yellow virus",
    "Tomato mold leaf",
    "Tomato two spotted spider mites leaf",
    "grape leaf",
    "grape leaf black rot",
]


def _healthy(crop: str) -> dict[str, str | None]:
    return {
        "crop": crop,
        "display_name": f"Healthy {crop} Leaf",
        "description": "No disease symptoms detected.",
        "symptoms": None,
        "recommendation": "Continue regular monitoring, balanced fertilization and routine field sanitation.",
    }


DISEASE_INFO: dict[str, dict[str, str | None]] = {
    "Apple Scab Leaf": {
        "crop": "Apple",
        "display_name": "Apple Scab",
        "description": "A fungal disease (Venturia inaequalis) that thrives in cool, wet spring weather and overwinters in fallen leaves.",
        "symptoms": "Olive-green to black velvety spots on leaves and fruit; infected leaves may yellow and drop early; fruit can develop corky, cracked lesions.",
        "recommendation": "Rake and destroy fallen leaves to remove the overwintering source. Apply a protectant fungicide starting at bud break in scab-prone seasons, and favor resistant varieties where possible.",
    },
    "Apple leaf": _healthy("Apple"),
    "Apple rust leaf": {
        "crop": "Apple",
        "display_name": "Cedar Apple Rust",
        "description": "A fungal disease that needs both an apple tree and a nearby juniper/cedar host to complete its life cycle.",
        "symptoms": "Bright yellow-orange spots on leaves that enlarge through summer, with small black dots appearing on the upper spot surface.",
        "recommendation": "Remove nearby juniper/cedar hosts if practical, or apply a protectant fungicide from pink bud stage through several weeks after petal fall.",
    },
    "Bell_pepper leaf": _healthy("Bell Pepper"),
    "Bell_pepper leaf spot": {
        "crop": "Bell Pepper",
        "display_name": "Bacterial Leaf Spot (Pepper)",
        "description": "A bacterial disease that spreads rapidly in warm, wet, humid conditions, often via splashing water and contaminated tools or seed.",
        "symptoms": "Small, dark, water-soaked spots on leaves and fruit that may have a yellow halo; heavily spotted leaves can yellow and drop.",
        "recommendation": "Use certified disease-free seed/transplants, avoid working in wet fields, rotate crops, and apply a copper-based bactericide preventively in humid weather.",
    },
    "Blueberry leaf": _healthy("Blueberry"),
    "Cherry leaf": _healthy("Cherry"),
    "Corn Gray leaf spot": {
        "crop": "Corn (Maize)",
        "display_name": "Gray Leaf Spot",
        "description": "A fungal disease (Cercospora zeae-maydis) that survives in corn residue and spreads in warm, humid conditions with heavy dew.",
        "symptoms": "Small tan to gray rectangular lesions running parallel to leaf veins, which can merge and blight large areas of the leaf.",
        "recommendation": "Rotate away from corn for a season, till under infected residue, and choose resistant hybrids. Fungicide can help if pressure is high at a critical growth stage.",
    },
    "Corn leaf blight": {
        "crop": "Corn (Maize)",
        "display_name": "Northern Leaf Blight",
        "description": "A fungal disease (Exserohilum turcicum) that overwinters in crop residue and spreads in humid weather.",
        "symptoms": "Long, cigar-shaped grayish-green to tan lesions on leaves, typically starting on lower leaves and moving upward.",
        "recommendation": "Rotate crops, till residue, and plant resistant hybrids. Fungicide can protect yield if disease appears before or during tasseling.",
    },
    "Corn rust leaf": {
        "crop": "Corn (Maize)",
        "display_name": "Common Rust",
        "description": "A fungal disease (Puccinia sorghi) that produces wind-dispersed spores and favors cool, moist conditions.",
        "symptoms": "Small, cinnamon-brown, powdery pustules scattered on both leaf surfaces, darkening as the season progresses.",
        "recommendation": "Most modern hybrids tolerate common rust well; fungicide is rarely needed unless infection is severe and the crop is still young.",
    },
    "Peach leaf": _healthy("Peach"),
    "Potato leaf early blight": {
        "crop": "Potato",
        "display_name": "Potato Early Blight",
        "description": "A fungal disease (Alternaria solani) that typically appears on older, lower leaves first, especially on stressed plants.",
        "symptoms": "Dark brown spots with concentric 'target' rings, surrounded by a yellow halo; heavily infected leaves yellow and die early.",
        "recommendation": "Rotate crops away from potato/tomato, ensure balanced nitrogen to avoid plant stress, and apply fungicide once early spots appear, especially in warm, humid weather.",
    },
    "Potato leaf late blight": {
        "crop": "Potato",
        "display_name": "Potato Late Blight",
        "description": "A fast-moving, historically devastating disease (Phytophthora infestans, the Irish Famine pathogen) that spreads explosively in cool, wet weather.",
        "symptoms": "Water-soaked, dark green to black lesions on leaves that expand rapidly, often with white fungal growth on the underside in humid conditions; can destroy a field within days.",
        "recommendation": "Act immediately — this disease spreads fast. Remove and destroy infected plants, apply a protectant/curative fungicide without delay, avoid overhead irrigation, and warn neighboring farmers since it spreads readily between fields.",
    },
    "Raspberry leaf": _healthy("Raspberry"),
    "Soyabean leaf": _healthy("Soybean"),
    "Squash Powdery mildew leaf": {
        "crop": "Squash",
        "display_name": "Squash Powdery Mildew",
        "description": "A very common fungal disease of cucurbits, favored by warm days, high humidity and dense canopies.",
        "symptoms": "White, powdery fungal patches on the upper and lower leaf surface, spreading to cover the whole leaf; affected leaves can yellow and die.",
        "recommendation": "Improve airflow through spacing/pruning, avoid excess nitrogen, and apply sulfur or a labeled fungicide at first sign of white patches.",
    },
    "Strawberry leaf": _healthy("Strawberry"),
    "Tomato Early blight leaf": {
        "crop": "Tomato",
        "display_name": "Tomato Early Blight",
        "description": "A fungal disease (Alternaria solani) that usually starts on older, lower leaves of stressed plants.",
        "symptoms": "Dark brown spots with concentric target rings, surrounded by yellowing tissue; can also affect stems and fruit.",
        "recommendation": "Stake/prune for airflow, mulch to reduce soil splash onto leaves, rotate crops, and apply fungicide once spots appear.",
    },
    "Tomato Septoria leaf spot": {
        "crop": "Tomato",
        "display_name": "Tomato Septoria Leaf Spot",
        "description": "A fungal disease that spreads via rain splash and typically starts on lower, older leaves.",
        "symptoms": "Numerous small circular spots with dark borders and tan/gray centers, often with tiny black specks visible in the center.",
        "recommendation": "Remove and destroy affected lower leaves, mulch to reduce soil splash, avoid overhead watering, and apply fungicide if spreading continues.",
    },
    "Tomato leaf": _healthy("Tomato"),
    "Tomato leaf bacterial spot": {
        "crop": "Tomato",
        "display_name": "Tomato Bacterial Spot",
        "description": "A bacterial disease that spreads via rain splash, contaminated tools, and infected seed, especially in warm, wet conditions.",
        "symptoms": "Small, dark, greasy-looking spots on leaves and fruit, sometimes with a yellow halo; heavily infected leaves shrivel and drop.",
        "recommendation": "Use disease-free seed/transplants, avoid overhead watering and working wet plants, and apply copper-based bactericide preventively.",
    },
    "Tomato leaf late blight": {
        "crop": "Tomato",
        "display_name": "Tomato Late Blight",
        "description": "The same fast-spreading pathogen (Phytophthora infestans) that devastates potato; can wipe out a tomato crop within days in cool, wet weather.",
        "symptoms": "Large, water-soaked, dark green-to-brown lesions on leaves and stems, often with white fungal growth on leaf undersides in humid weather; fruit develops firm, dark, greasy-looking blotches.",
        "recommendation": "Act immediately — remove and destroy infected plants, apply fungicide right away, improve airflow, avoid overhead irrigation, and warn nearby growers since it spreads between fields quickly.",
    },
    "Tomato leaf mosaic virus": {
        "crop": "Tomato",
        "display_name": "Tomato Mosaic Virus",
        "description": "A highly stable, easily spread viral disease that can persist in soil and plant debris and spread via handling and tools.",
        "symptoms": "Mottled light and dark green mosaic patterning on leaves, leaf curling/distortion, and stunted growth.",
        "recommendation": "Remove and destroy infected plants, wash hands and disinfect tools between plants, avoid tobacco use near plants (a related virus source), and use resistant varieties.",
    },
    "Tomato leaf yellow virus": {
        "crop": "Tomato",
        "display_name": "Tomato Yellow Leaf Curl Virus",
        "description": "A viral disease transmitted by whiteflies; there is no cure once a plant is infected.",
        "symptoms": "Upward curling and yellowing of leaves, stunted growth, and significantly reduced fruit set.",
        "recommendation": "Remove and destroy infected plants to reduce virus spread, control whitefly populations (reflective mulch, sticky traps, appropriate insecticide), and use resistant varieties where available.",
    },
    "Tomato mold leaf": {
        "crop": "Tomato",
        "display_name": "Tomato Leaf Mold",
        "description": "A fungal disease especially common in humid greenhouses or densely planted, poorly ventilated fields.",
        "symptoms": "Pale yellow spots on the upper leaf surface with olive-green to grayish-purple velvety mold on the underside.",
        "recommendation": "Improve ventilation and reduce humidity around plants, avoid overhead watering, prune for airflow, and apply fungicide if it persists.",
    },
    "Tomato two spotted spider mites leaf": {
        "crop": "Tomato",
        "display_name": "Spider Mite Damage (Two-Spotted Spider Mite)",
        "description": "Damage from a tiny sap-sucking pest, not a disease, that thrives in hot, dry conditions and multiplies quickly.",
        "symptoms": "Fine yellow/white stippling or speckling on leaves, bronzing at high infestation, and fine webbing on the underside of leaves in severe cases.",
        "recommendation": "Hose down foliage to dislodge mites, encourage natural predators, and use a miticide or insecticidal soap if the infestation is heavy — avoid broad-spectrum insecticides that also kill mite predators.",
    },
    "grape leaf": _healthy("Grape"),
    "grape leaf black rot": {
        "crop": "Grape",
        "display_name": "Grape Black Rot",
        "description": "A fungal disease (Guignardia bidwellii) most damaging in warm, humid weather; overwinters in mummified berries and canes.",
        "symptoms": "Small tan leaf spots with dark borders; berries shrivel into hard black 'mummies'.",
        "recommendation": "Remove mummified berries and prune out infected canes. Apply fungicide from early shoot growth through berry set in disease-prone seasons.",
    },
}

assert set(DISEASE_INFO.keys()) == set(PLANT_DISEASE_CLASSES)
