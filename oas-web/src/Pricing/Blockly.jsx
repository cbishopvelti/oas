import { useEffect, useRef } from 'react';

import * as Blockly from 'blockly';
import 'blockly/blocks';
import * as En from 'blockly/msg/en';
import 'blockly/javascript';
import { luaGenerator } from 'blockly/lua';

Blockly.setLocale(En);
Blockly.Extensions.register('dynamic_user_output', function () {
  this.setOutput(true, null); // initially unknown

  this.setOnChange(function () {
    const inputBlock = this.getInputTargetBlock('user_var');

    if (!inputBlock) {
      this.setOutput(true, null);
      return;
    }

    const type = inputBlock.valueType || null;

    this.setOutput(true, type);
  });
});
Blockly.defineBlocksWithJsonArray([
  {
    "type": "set_total_price",
    "message0": "Total Price = %1",
    "args0": [
      {
        "type": "input_value",
        "name": "PRICE",
        "check": "Number" // <-- Forces the user to only plug in math/numbers
      }
    ],
    "colour": "#4CAF50", // A nice distinct green for the "Money" output
    "tooltip": "",
    "helpUrl": ""
  }, {
    "type": "data_user",
    "colour": '#9370DB',
    "message0": "User %1",
    "output": null,
    "args0": [
      {
        "type": "input_value",
        "name": "user_var",
        "check": "UserProperty"
      }
    ],
    "tooltip": "The that is attending this pricing bundle",
    "helpUrl": "",
    "extensions": ["dynamic_user_output"]
  },
  {
    "type": "data_user_member_status",
    // "colour": '#9370DB',
    // "message0": "Membership",
    // "output": "UserProperty",
    // "tooltip": "Select the users membership status"
  }, {
    "type": "membership_const",
    "tooltip": "Membership constent",
    "helpUrl": "",
    "message0": "%1 %2",
    "args0": [
      {
        "type": "field_dropdown",
        "name": "NAME",
        "options": [
          [
            "full_member",
            "full_member"
          ],
          [
            "temporary_member",
            "temporary_member"
          ],
          [
            "not_member",
            "not_member"
          ],
          [
            "x_member",
            "x_member"
          ]
        ]
      },
      {
        "type": "input_end_row",
        "name": "Membership",
        "align": "RIGHT"
      }
    ],
    "output": "Membership",
    "colour": '#9370DB',
    "inputsInline": true
  },
  {
    "type": "data_user_attending"
  }, {
    "type": "data_trainings",
    "output": "Array",
    "colour": "#9370DB",
    "message0": "Trainings",
    "tooltip": "Array of trainings in this price instance, the value is the base credit amount for that training"
  }
]);

luaGenerator.forBlock['set_total_price'] = function(block, generator) {
  const price = generator.valueToCode(block, 'PRICE', luaGenerator.ORDER_NONE) || '0';

  return `return ${price}\n`;
};

luaGenerator.forBlock["data_user"] = function(block, generator) {
  // 1. Grab the property string from the connected block (e.g., "membership_status")
  // We use ORDER_HIGH because we are about to attach it to an object with dot notation
  const propertyCode = generator.valueToCode(block, 'user_var', luaGenerator.ORDER_HIGH);

  // 2. If the user hasn't plugged anything in yet, just return 'user' (or nil)
  if (!propertyCode) {
    return ['user', luaGenerator.ORDER_ATOMIC];
  }

  // 3. Combine them to create standard Lua table access (e.g., user.membership_status)
  const code = `user.${propertyCode}`;

  // 4. Return the tuple
  return [code, luaGenerator.ORDER_HIGH];
};



luaGenerator.forBlock["membership_const"] = function(block, generator) {
  const dropdownValue = block.getFieldValue('NAME');
  return [`"${dropdownValue}"`, luaGenerator.ORDER_ATOMIC];
};

Blockly.Blocks['data_user_member_status'].init = function () {
  this.jsonInit({
    "message0": "Membership",
    "output": "UserProperty",
    "colour": "#9370DB",
    "tooltip": "Select the users membership status"
  });

  this.valueType = "Membership";
};
luaGenerator.forBlock["data_user_member_status"] = function(block, generator) {
  return ['membership_status', luaGenerator.ORDER_ATOMIC];
};

// Filled with the indexs
Blockly.Blocks['data_user_attending'].init = function () {
  this.jsonInit({
    "message0": "Attending",
    "tooltip": "Array of user attendancies for this event, values are the keys of trainings (1 indexed)",
    "colour": "#9370DB",
    "output": "UserProperty"
  })
  this.valueType = "Array"
}
luaGenerator.forBlock["data_user_attending"] = function(block, generator) {
  return ['attending', luaGenerator.ORDER_ATOMIC]
}

luaGenerator.forBlock["data_trainings"] = function(block, generator) {
  return ['trainings', luaGenerator.ORDER_ATOMIC]
}


export const BBlockly = ({
  blockly_conf,
  primaryWorkspace
}) => {
  const blocklyDiv = useRef(null);
  // const primaryWorkspace = useRef(null);

  useEffect(() => {
    if (!blocklyDiv.current) return;

    const workspace = Blockly.inject(blocklyDiv.current, {
      oneBasedIndex: true,
      toolbox: {
        kind: 'categoryToolbox',
        contents: [
          {
            kind: 'category',
            name: 'Data',
            colour: '#9370DB',
            contents: [
              { kind: 'block', type: 'data_user'},
              { kind: 'block', type: 'data_user_member_status'},
              { kind: 'block', type: 'data_user_attending'},
              { kind: 'block', type: 'membership_const'},
              { kind: 'block', type: 'data_trainings'}

            ]
          },
          { kind: 'sep' },
          {
            kind: 'category',
            name: 'Logic',
            categorystyle: 'logic_category',
            contents: [
              { kind: 'block', type: 'controls_if' },
              { kind: 'block', type: 'logic_compare' },
              { kind: 'block', type: 'logic_operation' },
              { kind: 'block', type: 'logic_negate' },
              { kind: 'block', type: 'logic_boolean' },
              { kind: 'block', type: 'logic_null' },
              { kind: 'block', type: 'logic_ternary' }
            ]
          },
          {
            kind: 'category',
            name: 'Loops',
            categorystyle: 'loop_category',
            contents: [
              { kind: 'block', type: 'controls_repeat_ext' },
              { kind: 'block', type: 'controls_whileUntil' },
              { kind: 'block', type: 'controls_for' },
              { kind: 'block', type: 'controls_forEach' },
              { kind: 'block', type: 'controls_flow_statements' }
            ]
          },
          {
            kind: 'category',
            name: 'Math',
            categorystyle: 'math_category',
            contents: [
              { kind: 'block', type: 'math_number', fields: { NUM: 1 } },
              { kind: 'block', type: 'math_arithmetic' },
              { kind: 'block', type: 'math_single' },
              { kind: 'block', type: 'math_trig' },
              { kind: 'block', type: 'math_constant' },
              { kind: 'block', type: 'math_number_property' },
              { kind: 'block', type: 'math_round' },
              { kind: 'block', type: 'math_on_list' },
              { kind: 'block', type: 'math_modulo' },
              { kind: 'block', type: 'math_constrain' },
              { kind: 'block', type: 'math_random_int' },
              { kind: 'block', type: 'math_random_float' }
            ]
          },
          // {
          //   kind: 'category',
          //   name: 'Text',
          //   categorystyle: 'text_category',
          //   contents: [
          //     { kind: 'block', type: 'text' },
          //     { kind: 'block', type: 'text_join' },
          //     { kind: 'block', type: 'text_append' },
          //     { kind: 'block', type: 'text_length' },
          //     { kind: 'block', type: 'text_isEmpty' },
          //     { kind: 'block', type: 'text_indexOf' },
          //     { kind: 'block', type: 'text_charAt' },
          //     { kind: 'block', type: 'text_getSubstring' },
          //     { kind: 'block', type: 'text_changeCase' },
          //     { kind: 'block', type: 'text_trim' },
          //     { kind: 'block', type: 'text_print' },
          //     { kind: 'block', type: 'text_prompt_ext' }
          //   ]
          // },
          {
            kind: 'category',
            name: 'Lists',
            categorystyle: 'list_category',
            contents: [
              { kind: 'block', type: 'lists_create_empty' },
              { kind: 'block', type: 'lists_create_with' },
              { kind: 'block', type: 'lists_repeat' },
              { kind: 'block', type: 'lists_length' },
              { kind: 'block', type: 'lists_isEmpty' },
              { kind: 'block', type: 'lists_indexOf' },
              { kind: 'block', type: 'lists_getIndex', extraState: { mode: 'GET', where: 'FROM_START' } },
              { kind: 'block', type: 'lists_setIndex' },
              { kind: 'block', type: 'lists_getSublist' },
              { kind: 'block', type: 'lists_split' },
              { kind: 'block', type: 'lists_sort' }
            ]
          },
          {
            kind: 'category',
            name: 'Colour',
            categorystyle: 'colour_category',
            contents: [
              { kind: 'block', type: 'colour_picker' },
              { kind: 'block', type: 'colour_random' },
              { kind: 'block', type: 'colour_rgb' },
              { kind: 'block', type: 'colour_blend' }
            ]
          },
          { kind: 'sep' },
          {
            kind: 'category',
            name: 'Functions',
            categorystyle: 'procedure_category',
            custom: 'PROCEDURE',
          },
          {
            kind: 'category',
            name: 'Variables',
            categorystyle: 'variable_category',
            custom: 'VARIABLE',
          },
        ]
      },
      trashcan: false,
      move: { scrollbars: true, drag: true, wheel: false }
    });
    workspace.addChangeListener(Blockly.Events.disableOrphans);

    const rootBlock = workspace.newBlock('set_total_price');
    // 1. Tell Blockly to generate the visual SVG shapes
    rootBlock.initSvg();

    // 2. Tell Blockly to draw it on the canvas
    rootBlock.render();
    rootBlock.setDeletable(false);
    // rootBlock.moveBy(200, 0);

    primaryWorkspace.current = workspace;

    const resize = () => {
      workspace.resizeContents();
      Blockly.svgResize(workspace);
      workspace.scrollCenter();
    };

    // ResizeObserver = correct fix
    const observer = new ResizeObserver(resize);
    observer.observe(blocklyDiv.current);

    if (blockly_conf) {
      Blockly.serialization.workspaces.load(blockly_conf, workspace);
    }

    // Initial resize
    resize();

    return () => {
      observer.disconnect();
      workspace.dispose();
      primaryWorkspace.current = null;
    };
  }, [blockly_conf]);

  return <div style={{ height: '512px', width: '100%', border: '1px solid #ccc', position: 'relative', }}>
    <div ref={blocklyDiv} style={{width: '100%', height: '100%'}}>
    </div>
  </div>
}
