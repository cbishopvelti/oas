import { useNavigate, useParams } from "react-router-dom"
import { Autocomplete, Box, FormControl, TextField,
  Switch, FormControlLabel, Button } from "@mui/material";
import { find, get, has, omit, pick, take } from 'lodash';
import { useState } from 'react';
import { useQuery, gql, useMutation } from "@apollo/client";
import { useEffect, useRef } from "react";
import { BBlockly } from "./Blockly";
import * as Blockly from "blockly";
import { parseErrors } from "../utils/util";

export const PricingInstance = () => {
  let { id } = useParams();
  if (id) {
    id = parseInt(id);
  }
  const [formData, setFormData] = useState({})
  const primaryWorkspace = useRef(null);
  const navigate = useNavigate();

  const onChange = (key, { isCheckbox } = {isCheckbox: false}) => (event) => {
    if (isCheckbox) {
      setFormData({
        ...formData,
        [key]: event.target.checked
      })
      return;
    }

    setFormData({
      ...formData,
      [key]: !event.target.value ? null : event.target.value
    });
  };

  const {data: pricingsData, refetch} = useQuery(gql`
    query {
      pricings {
        id,
        name,
        blockly_conf
      }
    }
  `)
  useEffect(() => {
    refetch();
  }, [])

  useEffect(() => {
    setFormData((pri) => ({
      ...pri,
      ...pick(formData.pricing, ["name", "blockly_conf"])
    }))
  }, [formData.pricing])

  const {data} = useQuery(gql`
    query($id: Int!) {
      pricing_instance(id: $id){
        id,
        name,
        is_active,
        pricing {
          id,
          name
        }
        blockly_conf
      }
    }
  `, {
    variables: {
      id: id
    },
    skip: !id
  })
  useEffect(() => {
    if (data?.pricing_instance) {
      setFormData(data.pricing_instance)
    }
  }, [data])

  const [mutation, {error: mutationError}] = useMutation(gql`
    mutation ($id: Int, $name: String!, $is_active: Boolean!, $pricing_id: Int!, $blockly_conf: Json!) {
      pricing_instance (
        id: $id,
        name: $name,
        is_active: $is_active,
        pricing_id: $pricing_id,
        blockly_conf: $blockly_conf
      ) {
        id
      }
    }
  `)
  const save = async () => {
    try {
      const blockly_conf = Blockly.serialization.workspaces.save(primaryWorkspace.current);
      await mutation({
        variables: {
          ...pick(formData, ["name", "id"]),
          is_active: formData.is_active|| false,
          pricing_id: formData.pricing.id,
          blockly_conf: JSON.stringify(blockly_conf, null, 2)
        }
      })
      // if (!id) {
      //   navigate(`/pricing/${get(data, "pricing.id")}`);
      // } else {
      //   refetch();
      // }
    } catch (error) {
      console.error(error)
    }

    refetch();
  }

  const errors = parseErrors([
    ...get(mutationError, "graphQLErrors", []),
  ])

  return <Box sx={{m: 2}}>
    <FormControl fullWidth sx={{mt: 2, mb: 2}}>
      <Autocomplete
        required
        options={get(pricingsData, "pricings", []).map(({ name, id }) => ({ id, label: name }))}
        value={
          formData.pricing
            ? { id: formData.pricing.id, label: formData.pricing.name }
            : null
        }
        renderInput={(params) => <TextField
          {...params}
          label="Pricing"
          required
          error={has(errors, "pricing")}
          helperText={get(errors, "pricing", []).join(" ")}
          />}
        clearOnBlur
        selectOnFocus
        handleHomeEndKeys
        isOptionEqualToValue={(option, value) => option.id === value.id}
        onChange={(event, newValue) => {
          if (!newValue){
            return
          }
          const pricingsArray = get(pricingsData, "pricings", []);
          const pricing = pricingsArray.find(({ id }) => id === newValue.id);

          setFormData((formData) => ({...formData, pricing: pricing}))
        }}
      />
    </FormControl>

    <FormControl fullWidth sx={{mt: 2, mb: 2}}>
      <FormControlLabel
        control={
          <Switch
            checked={get(formData, 'is_active', false) || false}
            onChange={(event) => {
              onChange('is_active', { isCheckbox: true })(event)
            }} />
        }
        label="Is active?"
        title="Activate/deactivate this pricing_instance and all training children"
      />
    </FormControl>

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
      <BBlockly blockly_conf={ formData.blockly_conf } primaryWorkspace={ primaryWorkspace} />
    </FormControl>

    <FormControl fullWidth sx={{mt: 2, mb: 2}}>
      <Button variant="contained" onClick={save}>
        Save
      </Button>
    </FormControl>

  </Box>
}
