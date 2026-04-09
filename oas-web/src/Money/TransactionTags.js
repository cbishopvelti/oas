import { gql, useMutation, useQuery } from "@apollo/client";
import { Autocomplete, Box, Chip, IconButton, TextField } from "@mui/material";
import { get, includes, set, filter as lodashFilter, differenceWith, differenceBy, pick, map, uniqBy, findIndex, slice, pullAt, find } from 'lodash'
import { createFilterOptions } from '@mui/material/Autocomplete';
import { useEffect } from "react";
import LabelIcon from '@mui/icons-material/Label';
import LabelOffIcon from '@mui/icons-material/LabelOff';

const filter = createFilterOptions();

const canAutoTag = (formData, tagName) => {
  if (get(formData, "who") && !get(formData, "who_member_id") &&
    !includes(["Gocardless", "Credits", "Tokens", "Membership", "Venue"], tagName)
  ) {
    return true
  }
  return false
}

export const TransactionTags = ({
  transactionTags = [],
  setTransactionTags = () => {},
  formData,
  setFormData,
  filterMode,
}) => {

  const {data, refetch } = useQuery(gql`
    query ($who: String) {
      transaction_tags {
        id,
        name
      }
      transaction_auto_tags(who: $who)
    }
  `, {
    variables: {
      who: get(formData, "who", null)
    },
  })

  let transaction_tags = uniqBy([...(get(data, 'transaction_tags', []) || []), ...transactionTags ], 'name')
  useEffect(() => {
    refetch()
  }, [formData.saveCount])

  useEffect(() => {
    if (filterMode) {
      return
    }

    const currentAutoTags = map(get(formData, "auto_tags", []), ({id}) => id);
    const missingTags = differenceBy(data?.transaction_auto_tags, currentAutoTags);

    if (missingTags.length === 0) {
      return
    }

    setFormData((oldFormData) => {
      const out = {
        ...oldFormData,
        auto_tags: uniqBy([
          ...get(oldFormData, "auto_tags", []),
          ...map(data?.transaction_auto_tags, (id) => {
            return find(transaction_tags, (tt) => tt.id === id)
          })
        ], (item) => item.id)
      }
      return out
    })
  }, [data?.transaction_auto_tags, data?.transaction_tags, get(formData, "who", null)])

  return <Autocomplete
    id="transactionTags"
    value={get(formData, "transaction_tags") || (filterMode && !transaction_tags.length && transaction_tags) || []}
    options={(transaction_tags).map(({name, id}) => ({ label: name, id, name }))}
    renderInput={(params) => <TextField {...params} label="Tags" />}
    multiple
    freeSolo
    selectOnFocus
    clearOnBlur
    handleHomeEndKeys
    isOptionEqualToValue={({id: optionId, name: optionName}, {id, name}) => {
      if (id) {
        return id == optionId
      }

      return optionName == name
    }}
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
      filtered = differenceBy(filtered, formData.transaction_tags, "name")

      return filtered;
    }}
    onChange={async (event, newValue, a, b, c, d) => {
      setFormData({
        ...formData,
        transaction_tags: newValue.map(({id, name}) => ({id, name: name}))
      })
      setTransactionTags(uniqBy([
        ...newValue.filter(({id}) => !id)
          .map(({id, name}) => ({id, name})),
        ...transactionTags
      ], 'name'))
    }}
    renderTags={(tagValue, getTagProps) =>
      tagValue.map((option, index) => {
        const { key, ...tagProps } = getTagProps({ index });

        const i = findIndex((formData.auto_tags || []), (tag) => {
          return tag.name === option.name
        })

        return (
          <Chip
            key={key}
            {...tagProps}
            label={<Box style={{ display: 'flex', alignItems: 'center' }}>
              <span>{option.name}</span>
              {canAutoTag(formData, option.name) && i === -1 && <IconButton
                size="small"
                // Add a little margin to separate from text
                sx={{ marginLeft: 0.5, padding: 0.25 }}
                onClick={(event) => {
                  event.stopPropagation();
                  setFormData((prevFormData) => {
                    return {
                      ...prevFormData,
                      auto_tags: [...(prevFormData.auto_tags || []), option]
                    }
                  })
                }}
                title="Auto tag disabled, click to enable; Auto tagging will tag any future transaction with this tag which has the same 'who'"
              >
                <LabelIcon
                  fontSize="small"
                  sx={{ color: "#0000EE;" }}

                />
              </IconButton>}
              {canAutoTag(formData, option.name) && i >= 0 && <IconButton
                size="small"
                // Add a little margin to separate from text
                sx={{ marginLeft: 0.5, padding: 0.25 }}
                onClick={(event) => {
                  event.stopPropagation();
                  setFormData((prevFormData) => {

                    const out = {
                      ...prevFormData,
                      auto_tags: prevFormData.auto_tags.toSpliced(i, 1)
                    }
                    return out
                  })
                }}
                title="Auto tag Enabled, click to disable."
              >
                <LabelOffIcon
                  fontSize="small"
                />
              </IconButton>}
            </Box>
            }

          />
        );
      })}
  />
}
