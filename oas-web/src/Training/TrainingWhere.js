import { useEffect, useState } from 'react'
import { useQuery, gql } from "@apollo/client";
import { find, get, has } from "lodash";
import { Autocomplete, TextField, createFilterOptions } from '@mui/material'


export const TrainingWhere = ({
  formData,
  setFormData,
  errors
}) => {
  const filter = createFilterOptions();

  const { data, refetch } = useQuery(gql`
    query {
      training_wheres {
        id,
        name
      }
    }
  `);
  useEffect(() => {
    refetch()
  }, [formData.saveCount])
  const trainingWhere = get(data, 'training_wheres', [])

  // || get(formData, 'training_where.name')
  return <Autocomplete
    id="training_where"
    freeSolo
    required
    value={get(formData, 'training_where.name')  || ''}
    options={(trainingWhere || []).map(({name, id}) => ({label: name, name, id }))}
    renderInput={(params) => <TextField
      {...params}
      label="Venue"
      required
      error={has(errors, "training_where")}
      helperText={get(errors, "training_where", []).join(" ")}
      />}
    filterOptions={(options, params) => {

      const filtered = filter(options, params);

      const { inputValue } = params;

      let add = []
      const isExisting = options.some((option) => inputValue === option.label);
      if (inputValue && !isExisting) {
        add = [{label: `Create "${inputValue}"`, name: inputValue}]
      }

      return [...filtered, ...add];
    }}
    clearOnBlur
    selectOnFocus
    handleHomeEndKeys
    onChange={(event, newValue, a, b, c, d) => {
      if (!newValue) {
        return;
      }

      const id = newValue instanceof String ? find(trainingWhere, (name) => name === newValue).id : newValue.id

      const objToSet = {
        ...formData,
        training_where: {
          name: newValue instanceof String ? newValue : newValue.name,
          ...(id ? {id: id} : {} )
        }
      }
      setFormData(objToSet)
    }}
  />
}
