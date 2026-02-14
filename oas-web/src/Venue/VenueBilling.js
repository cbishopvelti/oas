import { FormControl, InputLabel, Select, MenuItem, TextField } from "@mui/material"
import { get, has } from 'lodash'

export const VenueBilling = ({
  formData, setFormData, errors,
  onChange,
  prefix }) => {

  return <><FormControl fullWidth sx={{ m: 2 }}>
    <InputLabel required id="billing-type">Billing type</InputLabel>
    <Select
      labelId="billing-type"
      label="Billing type"
      value={get(formData, `${prefix}billing_type`, '') || ""}
      onChange={onChange({formData, setFormData, key: `${prefix}billing_type`})}
    >
      <MenuItem value="">None</MenuItem>
      <MenuItem value="PER_HOUR">Per hour</MenuItem>
      <MenuItem value="PER_ATTENDEE">Per attendee</MenuItem>
      <MenuItem value="FIXED">Fixed</MenuItem>
    </Select>
  </FormControl>

  {get(formData, `${prefix}billing_type`) && !prefix &&
    <FormControl fullWidth sx={{m: 2}}>
      <TextField
        id="gocardless_name"
        label="Gocardless Name"
        value={get(formData, "gocardless_name", '') || ''}
        onChange={onChange({formData, setFormData, key: 'gocardless_name'})}
        error={has(errors, "gocardless_name")}
        helperText={get(errors, "gocardless_name", []).join(" ")}
      />
    </FormControl>
  }

  {get(formData, `${prefix}billing_type`) === "PER_HOUR" &&
    <FormControl fullWidth sx={{ m: 2 }}>
      <TextField
        id="billing_config"
        label="Amount per Hour"
        required
        inputMode="numeric"
        pattern="[0-9\.]*"
        value={get(formData, `${prefix}billing_config.per_hour`, "") || ''}
        onChange={onChange({ formData, setFormData, key: `${prefix}billing_config.per_hour` })}
        error={has(errors, `${prefix}billing_config`)}
        helperText={get(errors, `${prefix}billing_config`, []).join(" ")}
      />
    </FormControl>
  }

    {get(formData, `${prefix}billing_type`) === "PER_ATTENDEE" &&
      <FormControl fullWidth sx={{ m: 2 }}>
        <TextField
          id="billing_config"
          label="Amount per Attendee"
          required
          value={get(formData, `${prefix}billing_config.per_attendee`, "") || ''}
          onChange={onChange({ formData, setFormData, key: `${prefix}billing_config.per_attendee` })}
          error={has(errors, `${prefix}billing_config`)}
          helperText={get(errors, `${prefix}billing_config`, []).join(" ")}
          inputMode="numeric"
          pattern="[0-9\.]*"
        />
      </FormControl>}

    {get(formData, `${prefix}billing_type`) === "FIXED" &&
      <FormControl fullWidth sx={{ m: 2 }}>
        <TextField
          id="billing_config"
          label="Fixed amount"
          required
          value={get(formData, `${prefix}billing_config.fixed`, "") || ''}
          onChange={onChange({ formData, setFormData, key: `${prefix}billing_config.fixed` })}
          error={has(errors, `${prefix}billing_config`)}
          helperText={get(errors, `${prefix}billing_config`, []).join(" ")}
          inputMode="numeric"
          pattern="[0-9\.]*"
        />
      </FormControl>}
  </>
}
