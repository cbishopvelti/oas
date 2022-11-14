import { gql, useMutation, useQuery } from "@apollo/client";
import { Autocomplete, TextField } from "@mui/material";
import { get, includes, set, filter as lodashFilter, differenceWith, differenceBy, pick, map } from 'lodash'
import { createFilterOptions } from '@mui/material/Autocomplete';
import { useEffect } from "react";

const filter = createFilterOptions();


export const TrainingTags = ({
  formData, 
  setFormData,
  filterMode
}) => {

  const {data, refetch } = useQuery(gql`
    query {
      training_tags {
        id,
        name
      }
    }
  `)
  let training_tags = get(data, 'training_tags', [])
  useEffect(() => {
    refetch()
  }, [formData.saveCount])
  
  
  const [mutate] = useMutation(gql`
    mutation ($name: String!) {
      insert_training_tag(name: $name) {
        id
      }
    }
  `)

  const trainingTagsValue = get(formData, "training_tags", [])

  return <Autocomplete
    id="trainingTags"
    value={trainingTagsValue /*|| [{id: 1, name: "existing_test"}]*/}
    options={(training_tags).map(({name, id}) => ({ label: name, id, name }))}
    renderInput={(params) => <TextField {...params} required label="Tags" />}
    multiple
    freeSolo
    selectOnFocus
    clearOnBlur
    handleHomeEndKeys
    getOptionLabel={(option) => {
      // Value selected with enter, right from the input
      if (typeof option === 'string') {
        return option;
      }
      // Regular option
      return option.label || option.name;
    }}
    filterOptions={(options, params, b, c) => {

      let filtered = filter(options, params, b, c);

      const { inputValue } = params;

      const isExisting = options.some((option) => inputValue === option.name);
      if (inputValue !== '' && !isExisting && !filterMode) {
        filtered.push({
          name: inputValue,
          label: `Create "${inputValue}"`,
        });
      }

      // Only allow unique options
      filtered = differenceBy(filtered, formData.training_tags, "id")

      return filtered;
    }}
    onChange={async (event, newValue, a, b, c, d) => {
      // const createPromises = newValue
      //   .filter((item) => !item.id)
      //   .map(async (item) => {
      //     const result = await mutate({
      //       variables: {
      //         name: item.name
      //       }
      //     })

      //     set(item, "id", get(result, "data.insert_training_tag.id"))
      //   })
      // const result = await Promise.all(createPromises);
      // if (result.length > 0) {
      //   refetch();
      // }

      setFormData({
        ...formData,
        training_tags: newValue.map(({id, name}) => ({id, name: name}))
      })
    }}
  />
}