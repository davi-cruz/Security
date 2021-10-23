// You MUST minify this script version to add to Logic App Inline Code action
// Commented snippet to test this from a local entity sample file
// $ node Integration-EntityToMarkdown.js > Test.md
// Test
// var fs = require('fs');
// var path = require('path');
// let jsonPath = path.join(__dirname, 'sample.json');
// let text = fs.readFileSync(jsonPath, 'utf8');
// var objJSON = JSON.parse(text);
// Logic App 
let objJSON = workflowContext.trigger.outputs.body.object.properties.relatedEntities;

function tableMD() {
    // List entity Types
    var arrKind = [];
    objJSON.forEach(objEntity => {
        arrKind.push(objEntity.kind);
    });
    var setKind = new Set(arrKind);

    // Dynamically builds entity tables by kind
    var result = ["### Entities", ""];
    setKind.forEach(strKind => {
        result.push("");
        result.push("#### Entity Type: **" + strKind + "**");
        result.push("");
        scope = objJSON.filter(entity => entity.kind == strKind);

        // List all key values forspecified entity kind
        keys = [];
        scope.forEach(entity => {
            Object.keys(entity.properties).forEach(key => {
                keys.push(key);
            });
        });

        // Builds markdown header
        tableHeader = [];
        tableDelimiter = [];
        new Set(keys).forEach(key => {
            tableHeader.push(key);
            tableDelimiter.push("-");
        });
        result.push('| ' + tableHeader.join(" | ") + " |");
        result.push('| ' + tableDelimiter.join(" | ") + " |");

        // Populate table with available data
        scope.forEach(entity => {
            tableRow = [];
            keys.forEach(key => {
                if (entity.properties[key]) {
                    if (key == 'additionalData' || key == "location") {
                        // Stringfy dynamic fields
                        tableRow.push(JSON.stringify(entity.properties[key]));
                    }
                    else {
                        tableRow.push(entity.properties[key]);
                    }
                }
                else {
                    tableRow.push("");
                }
            });
            // Append line to result array
            result.push('| ' + tableRow.join(" | ") + " |");
        });
    });

    // Concatenate array in a single string
    output = result.join("\n");

    // Test
    //console.log(output);
    return output;
}

tableMD(objJSON);