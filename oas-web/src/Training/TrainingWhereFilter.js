import { gql, useMutation, useQuery } from "@apollo/client";
import { Autocomplete, TextField } from "@mui/material";
import { get, includes, set, filter as lodashFilter, differenceWith, differenceBy, pick, map } from 'lodash'
import { createFilterOptions } from '@mui/material/Autocomplete';
import { useEffect } from "react";

const filter = createFilterOptions();


export const TrainingWhereFilter = ({
  parentData,
  formData, 
  setFormData
}) => {
  const {data, refetch } = useQuery(gql`
    query {
      training_where {
        id,
        name
      }
    }
  `)
  let training_where = get(data, 'training_where', [])

  useEffect(() => {
    refetch()
  }, [parentData])

  return <Autocomplete
    id="trainingWhere"
    value={formData.training_where || training_where /*|| [{id: 1, name: "existing_test"}]*/}
    options={(training_where).map(({name, id}) => ({ label: name, id, name }))}
    renderInput={(params) => <TextField {...params} label="Where" />}
    multiple
    selectOnFocus
    freeSolo
    clearOnBlur
    handleHomeEndKeys
    getOptionLabel={(option) => {
      return option.name;
    }}
    filterOptions={(options, params, b, c) => {

      let filtered = filter(options, params, b, c);

      // Only allow unique options
      filtered = differenceBy(filtered, formData.training_where, "id")

      return filtered;
    }}
    onChange={async (event, newValue, a, b, c, d) => {
      setFormData({
        ...formData,
        training_where: newValue.map(({id, name}) => ({id, name: name}))
      })
    }}
  />
}