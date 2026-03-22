const { ModelArmorClient } = require('@google-cloud/modelarmor').v1;

async function createTemplate() {
    // Requires GOOGLE_CLOUD_PROJECT to be set
    const projectId = process.env.GOOGLE_CLOUD_PROJECT;
    if (!projectId) {
        throw new Error("GOOGLE_CLOUD_PROJECT environment variable must be set!");
    }

    const client = new ModelArmorClient();
    const location = 'us-central1';
    const templateId = 'workshop-api-template';
    const parent = `projects/${projectId}/locations/${location}`;

    const request = {
        parent: parent,
        templateId: templateId,
        template: {
            name: `${parent}/templates/${templateId}`,
            filterConfig: {
                piAndJailbreakFilterSettings: {
                    enforcement: 'ENABLED'
                }
            }
        }
    };

    console.log(`Creating Model Armor template '${templateId}' in ${parent}...`);
    try {
        const [response] = await client.createTemplate(request);
        console.log("✅ Success! Template created successfully.");
        console.log("Template Name (Copy this into your .env file):");
        console.log("--------------------------------------------------");
        console.log(response.name);
        console.log("--------------------------------------------------");
    } catch (err) {
        if (err.code === 6) { // ALREADY_EXISTS code in gRPC
            console.log("⚠️ Template already exists!");
            console.log(`Template Name: ${parent}/templates/${templateId}`);
        } else {
            console.error("❌ Failed to create template:", err);
        }
    }
}

createTemplate().catch(console.error);
