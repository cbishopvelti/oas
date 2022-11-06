import { set, setWith, clone, get, has } from "lodash"
import { FormControl, TextField, Switch, FormControlLabel, FormHelperText } from '@mui/material'

const onChange = ({formData, setFormData, isCheckbox, key}) => (event) => {
  let value = event.target.value

  if (isCheckbox) {
    value = event.target.checked
  }

  formData = set(clone(formData), key, value)
  setFormData(formData)
}


export const MemberDetails = ({
  errors,
  formData, 
  setFormData  
}) => {
  return <>
    <FormControl fullWidth sx={{m: 2}}>
      <TextField
        id="phone"
        required
        label={'Phone Number'}
        value={get(formData, 'member_details.phone', '')}
        onChange={onChange({formData, setFormData, key: "member_details.phone"})}
        error={has(errors, "phone")}
        helperText={get(errors, "phone", []).join(" ")}
      />
    </FormControl>
    <FormControl fullWidth sx={{m: 2}}>
      <TextField
        id="address"
        required
        label={'Address'}
        value={get(formData, 'member_details.address', '')}
        onChange={onChange({formData, setFormData, key: "member_details.address"})}
        multiline={true}
        minRows={2}
        error={has(errors, "address")}
        helperText={get(errors, "address", []).join(" ")}
      />
    </FormControl>
    <FormControl fullWidth sx={{m: 2}}>
      <TextField
        required
        id="dob"
        label="Date of Birth"
        value={get(formData, "member_details.dob", '')}
        type="date"
        onChange={
          onChange({formData, setFormData, key: "member_details.dob"})
        }
        InputLabelProps={{
          shrink: true,
        }}
        error={has(errors, "dob")}
        helperText={get(errors, "dob", []).join(" ")}
        />
    </FormControl>
    <FormControl fullWidth sx={{m: 2}}>
      <TextField
        required
        id="nok_name"
        label="Next of Kin Name"
        value={get(formData, "member_details.nok_name", '')}
        onChange={onChange({formData, setFormData, key: "member_details.nok_name"})}
        error={has(errors, "nok_name")}
        helperText={get(errors, "nok_name", []).join(" ")}
      />
    </FormControl>

    <FormControl fullWidth sx={{m: 2}}>
      <TextField
        required
        id="nok_email"
        label="Next of Kin Email"
        value={get(formData, "member_details.nok_email", '')}
        onChange={onChange({formData, setFormData, key: "member_details.nok_email"})}
        error={has(errors, "nok_email")}
        helperText={get(errors, "nok_email", []).join(" ")}
      />
    </FormControl>
    <FormControl fullWidth sx={{m: 2}}>
      <TextField
        id="nok_phone"
        required
        label={'Next of Kin Phone Number'}
        value={get(formData, 'member_details.nok_phone', '')}
        onChange={onChange({formData, setFormData, key: "member_details.nok_phone"})}
        error={has(errors, "nok_phone")}
        helperText={get(errors, "nok_phone", []).join(" ")}
      />
    </FormControl>
    <FormControl fullWidth sx={{m: 2}}>
      <TextField
        id="nok_address"
        required
        label={'Next of Kin Address'}
        value={get(formData, 'member_details.nok_address', '')}
        onChange={onChange({formData, setFormData, key: "member_details.nok_address"})}
        multiline={true}
        minRows={2}
        error={has(errors, "nok_address")}
        helperText={get(errors, "nok_address", []).join(" ")}
      />
    </FormControl>
    <FormControl fullWidth sx={{m: 2}}>
      <FormControlLabel
        control={
          <Switch
            checked={get(formData, 'member_details.agreed_to_tac', false)}
            value={get(formData, 'member_details.agreed_to_tac', false)}
            onChange={onChange({formData, setFormData, key: "member_details.agreed_to_tac", isCheckbox: true})}
          />
        }
        label="They have agreed to the waver"
        />
        <FormHelperText
          error={has(errors, 'agreed_to_tac')}>
          {get(errors, 'agreed_to_tac', []).join(' ')}
        </FormHelperText>
    </FormControl>
  </>
}
