let objJSON=workflowContext.trigger.outputs.body.object.properties.relatedEntities;function tableMD(){var e=[];objJSON.forEach((t=>{e.push(t.kind)}));var t=new Set(e),o=["### Entities",""];return t.forEach((e=>{o.push(""),o.push("#### Entity Type: **"+e+"**"),o.push(""),scope=objJSON.filter((t=>t.kind==e)),keys=[],scope.forEach((e=>{Object.keys(e.properties).forEach((e=>{keys.push(e)}))})),tableHeader=[],tableDelimiter=[],new Set(keys).forEach((e=>{tableHeader.push(e),tableDelimiter.push("-")})),o.push("| "+tableHeader.join(" | ")+" |"),o.push("| "+tableDelimiter.join(" | ")+" |"),scope.forEach((e=>{tableRow=[],keys.forEach((t=>{e.properties[t]?"object"==typeof e.properties[t]?tableRow.push(JSON.stringify(e.properties[t])):tableRow.push(e.properties[t]):tableRow.push("")})),o.push("| "+tableRow.join(" | ")+" |")}))})),output=o.join("\n"),output}tableMD(objJSON);