import { gql, useMutation, useQuery } from "@apollo/client"
import { useNavigate, useOutletContext, useParams } from "react-router-dom";
import { get, has } from "lodash";
import { useEffect, useState, useRef, useCallback, useLayoutEffect } from "react";
import { Box, FormControl, TextField, Button } from "@mui/material";
import { parseErrors } from "../utils/util";
import { BBlockly } from "./Blockly";
import * as Blockly from 'blockly';


export const Pricing = () => {
  let { id } = useParams();
  if (id) {
    id = parseInt(id);
  }

  const primaryWorkspace = useRef(null);
  const navigate = useNavigate();
  const { setTitle } = useOutletContext();
  const [formData, setFormData] = useState({
    name: ""
  })

  const { data, error, refetch } = useQuery(gql`query ($id: Int!) {
    pricing(id: $id) {
      id,
      name,
      blockly_conf
    }
  }`, {
    variables: {
      id: id
    },
    skip: !id
  })
  useEffect(() => {
    if (data?.pricing) {
      setFormData(data.pricing)
    }
  }, [data])

  const [pricing, { error: mutationError }] = useMutation(gql`
    mutation ($id: Int, $name: String!, $blockly_conf: Json!) {
      pricing(id: $id, name: $name, blockly_conf: $blockly_conf) {
        id
      }
    }
  `);
  const save = async () => {
    const blockly_conf = Blockly.serialization.workspaces.save(primaryWorkspace.current);

    try {
      const { data } = await pricing({
        variables: {
          ...formData,
          blockly_conf: JSON.stringify(blockly_conf, null, 2)
        }
      })
      if (!id) {
        navigate(`/pricing/${get(data, "pricing.id")}`);
      } else {
        refetch();
      }
    } catch (error) {
      console.error("Pricing error", error)
    }
  }

  const errors = parseErrors([
    ...get(mutationError, "graphQLErrors", []),
  ]);

  useEffect(() => {
    if (!id) {
      setTitle("New Pricing");
    } else {
      setTitle(`Editing Pricing: ${get(data, 'pricing.name', id)}`);
    }
  }, [id, data, setTitle]);

  const onChange = (key) => (event) => {
    setFormData({
      ...formData,
      [key]: !event.target.value ? null : event.target.value
    });
  };


  // useLayoutEffect(() => {
  //   if (primaryWorkspace.current) {
  //     Blockly.svgResize(primaryWorkspace.current);
  //   }
  // });

  return <Box sx={{m: 2}}>
    <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
      <TextField
        required
        id="name"
        label="Name"
        value={get(formData, "name", '')}
        type="text"
        onChange={onChange("name")}
        error={has(errors, "name")}
        helperText={get(errors, "name", []).join(" ")}
      />
    </FormControl>
    <FormControl fullWidth sx={{mt: 2, mb: 2}}>
      <BBlockly blockly_conf={get(data, "pricing.blockly_conf") } primaryWorkspace={primaryWorkspace} />
    </FormControl>
    <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
      <Button variant="contained" onClick={save}>
        Save
      </Button>
    </FormControl>
  </Box>
}
